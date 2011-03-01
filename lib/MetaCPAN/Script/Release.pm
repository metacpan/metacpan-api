package MetaCPAN::Script::Release;
use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';
use Log::Contextual qw( :log );

use Path::Class qw(file dir);
use Archive::Tar       ();
use File::Temp         ();
use CPAN::Meta         ();
use DateTime           ();
use List::Util         ();
use Module::Metadata   ();
use File::stat         ();
use CPAN::DistnameInfo ();

use feature 'say';
use MetaCPAN::Document::Release;
use MetaCPAN::Document::Distribution;
use MetaCPAN::Document::File;
use MetaCPAN::Document::Dependency;
use MetaCPAN::Document::Module;
use MetaCPAN::Script::Latest;
use DateTime::Format::Epoch::Unix;
use File::Find::Rule;
use Try::Tiny;
use LWP::UserAgent;

has latest => ( is => 'ro', isa => 'Bool', default => 0 );
has age => ( is => 'ro', isa => 'Int' );
has verbose => ( is => 'ro', isa => 'Bool', default => 0 );

sub main {
    my $tarball = shift;
    unshift( @ARGV, "release" );
    __PACKAGE__->new_with_options->run;
}

sub run {
    my $self = shift;
    my ( undef, @args ) = @{ $self->extra_argv };
    my @files;
    for (@args) {
        if ( -d $_ ) {
            log_info { "Looking for tarballs in $_" };
            my $find = File::Find::Rule->new->file->name('*.tar.gz');
            $find = $find->ctime( ">" . (time - $self->age * 3600) )
              if ( $self->age );
            push( @files, sort $find->in($_) );
        } elsif ( -f $_ ) {
            push( @files, $_ );
        } elsif ( $_ =~ /^https?:\/\// && CPAN::DistnameInfo->new($_)->cpanid )
        {
            my $d = CPAN::DistnameInfo->new($_);
            my $file =
              Path::Class::File->new( qw(var tmp http),
                                     'authors',
                                     MetaCPAN::Document::Author::_build_dir(
                                                                      $d->cpanid
                                     ), $d->filename );
            my $ua = LWP::UserAgent->new( parse_head => 0,
                                          env_proxy  => 1,
                                          agent      => "metacpan",
                                          timeout    => 30, );
            $file->dir->mkpath;
            log_info { "Downloading $_" };
            $ua->mirror( $_, $file );
            if ( -e $file ) {
                push( @files, $file );
            } else {
                log_error { "Downloading $_ failed" };
            }
        } else {
            log_error { "Dunno what $_ is" };
        }
    }
    log_info { scalar @files, " tarballs found" } if ( @files > 1 );
    while ( my $file = shift @files ) {
        try { $self->import_tarball($file) } catch { log_fatal { $_ } };
    }
}

sub import_tarball {
    my ( $self, $tarball ) = @_;
    log_info { "Processing $tarball" };
    $tarball = Path::Class::File->new($tarball);

    log_debug { "Opening tarball in memory" };
    my $at = Archive::Tar->new($tarball);
    my $tmpdir = dir(File::Temp::tempdir);
    my $d      = CPAN::DistnameInfo->new($tarball);
    my ( $author, $archive, $name ) =
      ( $d->cpanid, $d->filename, $d->distvname );
    my $version = MetaCPAN::Util::fix_version( $d->version );
    my $meta = CPAN::Meta->new(
                                { version => $version || 0,
                                  license => 'unknown',
                                  name    => $d->dist,
                                  no_index => {
                                      directory => [qw(t xt inc)]
                                  }
                                } );

    my @files;
    my $meta_file;
    log_debug { "Gathering files" };
    my @list = $at->get_files;
    while ( my $child = shift @list ) {
        if ( ref $child ne 'HASH' ) {
            $meta_file = $child if ( $child->full_path =~ /^[^\/]+\/META\./ );
            my $stat = { map { $_ => $child->$_ } qw(mode uid gid size mtime) };
            my $fname = $child->full_path;
            $child->is_dir ? $fname =~ s/(.*\/)?(.*?)\//$2/ : $fname =~ s/.*\///;
            ( my $fpath = $child->full_path ) =~ s/.*?\///;
            my @level = split(/\//, $fpath);
            my $level = @level - 1;
            push( @files,
                  {  name         => $fname,
                     directory    => $child->is_dir ? 1 : 0,
                     level        => $level,
                     release      => $name,
                     distribution => $meta->name,
                     author       => $author,
                     full_path    => $child->full_path,
                     path         => $fpath,
                     stat         => $stat,
                     maturity     => $d->maturity,
                  } );
        }
    }

    # get better meta info from meta file
    try {
        $at->extract_file( $meta_file, $tmpdir->file( $meta_file->full_path ) );
        my $foo =
          CPAN::Meta->load_file( $tmpdir->file( $meta_file->full_path ) );
        $meta = $foo;
    } catch {
        log_error { "META file could not be loaded: $_" };
    } if ($meta_file);

    my $create =
      { map { $_ => $meta->$_ } qw(version name license abstract resources) };
    $create = { %$create,
                name         => $name,
                author       => $author,
                distribution => $meta->name,
                archive      => $archive,
                maturity     => $d->maturity,
                date         => $self->pkg_datestamp($tarball), };

    log_debug { "Indexing ", scalar @files, " files" };
    my $i = 1;
    foreach my $file (@files) {
        my $obj = MetaCPAN::Document::File->new(
            {  %$file,
               content_cb => sub { \( $at->get_content( $file->{full_path} ) ) }
            } );
        $obj->index( $self->es );
        $file->{abstract} = $obj->abstract;
        $file->{id}       = $obj->id;
    }

    my $release = MetaCPAN::Document::Release->new($create);
    $release->index( $self->es );

    my $distribution =
      MetaCPAN::Document::Distribution->new( { name => $meta->name } );
    $distribution->index( $self->es );

    log_debug { "Gathering dependencies" };

    # find dependencies
    my @dependencies;
    if ( my $prereqs = $meta->prereqs ) {
        while ( my ( $phase, $data ) = each %$prereqs ) {
            while ( my ( $relationship, $v ) = each %$data ) {
                while ( my ( $module, $version ) = each %$v ) {
                    push( @dependencies,
                          {  phase        => $phase,
                             relationship => $relationship,
                             module       => $module,
                             version      => $version,
                             release      => $release->name,
                          } );
                }
            }
        }
    }

    log_debug { "Indexing ", scalar @dependencies, " dependencies" };
    $i = 1;
    foreach my $dependencies (@dependencies) {
        $dependencies = MetaCPAN::Document::Dependency->new($dependencies);
        $dependencies->index( $self->es );
    }
    
    log_debug {  "Gathering modules" };
    # find modules
    my @modules;
    if ( keys %{ $meta->provides } && ( my $provides = $meta->provides ) ) {
        while ( my ( $module, $data ) = each %$provides ) {
            my $path = $data->{file};
            my $file =
              List::Util::first { $_->{path} =~ /\Q$path\E$/ } @files;
            push( @modules,
                  {  %$data,
                     name => $module,
                     file => $file,
                  } );
        }

    } elsif ( my $no_index = $meta->no_index ) {
        @files = grep { $_->{name} =~ /\.pm$/ } @files;
        foreach my $no_dir ( @{ $no_index->{directory} || [] } ) {
            @files =
              grep { $_->{path} !~ /^\Q$no_dir\E\// } @files;
        }

        foreach my $no_file ( @{ $no_index->{file} || [] } ) {
            @files = grep { $_->{path} !~ /^\Q$no_file\E/ } @files;
        }
        foreach my $file (@files) {
            eval {
                local $SIG{'ALRM'} =
                  sub { log_error { "Call to Module::Metadata timed out " }; die };
                alarm(5);
                $at->extract_file( $file->{full_path},
                                   $tmpdir->file( $file->{full_path} ) );
                my $info;
                {
                    local $SIG{__WARN__} = sub { };
                    $info = Module::Metadata->new_from_file(
                                          $tmpdir->file( $file->{full_path} ) );
                }
                push( @modules,
                      {  file => $file,
                         name => $_,
                         $info->version
                         ? ( version => $info->version->numify )
                         : () } ) for ( $info->packages_inside );
                alarm(0);
            };
        }
    }

    log_debug { "Indexing ", scalar @modules, " modules" };
    $i = 1;
    foreach my $module (@modules) {
        my $obj =
          MetaCPAN::Document::Module->new(
                                        %$module,
                                        file     => $module->{file}->{path},
                                        file_id  => $module->{file}->{id},
                                        abstract => $module->{file}->{abstract},
                                        release  => $release->name,
                                        date     => $release->date,
                                        distribution => $release->distribution,
                                        author       => $release->author,
                                        maturity     => $d->maturity, );
        $obj->index( $self->es );
    }
    
    if ( $self->latest ) {
        MetaCPAN::Script::Latest->new( distribution => $release->distribution )
          ->run;
    }
}

sub pkg_datestamp {
    my $self    = shift;
    my $archive = shift;
    my $date    = ( stat($archive) )[9];
    return DateTime::Format::Epoch::Unix->parse_datetime($date);

}

1;

__END__

=head1 SYNOPSIS

 # bin/metacpan ~/cpan/authors/id/A
 # bin/metacpan ~/cpan/authors/id/A/AB/ABRAXXA/DBIx-Class-0.08127.tar.gz
 # bin/metacpan http://cpan.cpantesters.org/authors/id/D/DA/DAGOLDEN/CPAN-Meta-2.110580.tar.gz

 # bin/metacpan ~/cpan --age 24 --latest

=head1 DESCRIPTION

This is the workhorse of MetaCPAN. It accepts a list of folders, files or urls
and indexes the releases. Adding C<--latest> will set the status to C<latest>
for the indexed releases If you are indexing more than one release, running
L<MetaCPAN::Script::Latest> afterwards is probably faster.

C<--age> sets the maximum age of the file in hours. Will be ignored when processing
individual files or an url.

If an url is specified the file is downloaded to C<var/tmp/http/>. This folder is not
cleaned up since L<MetaCPAN::Plack::Source> depends on it to extract the source of
a file. If the tarball cannot be find in the cpan mirror, it tries the temporary
folder. After a rsync this folder can be purged.