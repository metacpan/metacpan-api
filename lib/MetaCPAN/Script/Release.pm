package MetaCPAN::Script::Release;
use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';

use Path::Class::File  ();
use Archive::Extract   ();
use File::Temp         ();
use CPAN::Meta         ();
use DateTime           ();
use List::Util         ();
use Module::Metadata   ();
use File::stat         ();
use CPAN::DistnameInfo ();

use Modern::Perl;
use MetaCPAN::Document::Release;
use MetaCPAN::Document::Distribution;
use MetaCPAN::Document::File;
use MetaCPAN::Document::Dependency;
use MetaCPAN::Document::Module;
use DateTime::Format::Epoch::Unix;
use File::Find::Rule;
use Try::Tiny;
use LWP::UserAgent;

has reindex => ( is => 'ro', isa => 'Bool', default => 0 );

sub main {
    my $tarball = shift;
    unshift( @ARGV, "release" );
    __PACKAGE__->new_with_options->run;
}

sub run {
    my $self = shift;
    my ( undef, @args ) = @{ $self->extra_argv };
    my @files;
    warn @args;
    for (@args) {
        if ( -d $_ ) {
            print "Looking for files in $_ ... ";
            push( @files,
                  sort File::Find::Rule->new->file->name('*.tar.gz')->in($_) );
            say "done";
        } elsif ( -f $_ ) {
            push( @files, $_ );
        } elsif ( $_ =~
/^https?:\/\/.*\/authors\/id\/[A-Z]\/[A-Z][A-Z]\/([A-Z]+)\/(.*\/)*([^\/]+)$/ )
        {
            my $dir =
              Path::Class::Dir->new( File::Temp::tempdir, $1 );
            my $ua = LWP::UserAgent->new( parse_head => 0,
                                          env_proxy  => 1,
                                          agent      => "metacpan",
                                          timeout    => 30, );
            $dir->mkpath;
            my $file = $dir->file($3);
            print "Downloading $_ to temporary location ... ";
            $ua->mirror( $_, $file );
            if ( -e $file ) {
                say "done";
                push( @files, $file );
            } else {
                say "failed";
            }
        } else {
            say "Dunno what $_ is";
        }
    }
    for (@files) {
        try { $self->import_tarball($_) } catch { say "ERROR: $_" };
    }
}

sub import_tarball {
    my ( $self, $tarball ) = @_;
    say "Processing $tarball ...";
    ( my $author  = $tarball ) =~ s/^.*\/(.*?)\/[^\/]*$/$1/;
    ( my $archive = $tarball ) =~ s/^.*\/(.*?)$/$1/;
    $tarball = Path::Class::File->new($tarball);
    ( my $name = $tarball->basename ) =~ s/(\.tar)?\.gz$//;

    print "Extracting tarball to temporary directory ... ";
    my $ae = Archive::Extract->new( archive => $tarball );
    my $dir = Path::Class::Dir->new( File::Temp::tempdir );
    $ae->extract( to => $dir );
    say "done";

    my ($basedir) = $dir->children;
    my @children = $basedir->children;
    my @files;

    my $d = CPAN::DistnameInfo->new($tarball);
    my $meta = CPAN::Meta->new(
                                { version => $d->version,
                                  license => 'unknown',
                                  name    => $d->dist,
                                } );

    my $meta_file;
    print "Gathering files ... ";
    foreach my $child (@children) {
        if ( !$child->is_dir ) {
            my $relative = $child->relative($basedir);
            $meta_file = $child if ( $relative =~ /^META\./ );
            push( @files,
                  {  name         => $relative->basename,
                     binary       => -B $child ? 1 : 0,
                     release      => $name,
                     distribution => $meta->name,
                     author       => $author,
                     path         => $relative->as_foreign('Unix')->stringify,
                     stat         => File::stat::stat($child),
                     content      => \( scalar $child->slurp ) } );
        } elsif ( $child->is_dir ) {
            push( @children, $child->children );
        }
    }
    say "done";

    # get better meta info from meta file
    try {
        die unless ($meta_file);
        my $foo = CPAN::Meta->load_file($meta_file);
        $meta = $foo;
    };

    my $create =
      { map { $_ => $meta->$_ } qw(version name license abstract resources) };
    $create = { %$create,
                status       => $meta->release_status,
                name         => $name,
                author       => $author,
                distribution => $meta->name,
                archive      => $archive,
                date         => $self->pkg_datestamp($tarball) };

    $create->{distribution} = $meta->name;

    print "Indexing $#files files ... ";
    my $i = 1;
    foreach my $file (@files) {
        print $i++;
        $file = MetaCPAN::Document::File->new($file);
        $file->index( $self->es );
        print "\010 \010" x length( $i - 1 );
    }
    say "done";

    my $release = MetaCPAN::Document::Release->new($create);
    $release->index( $self->es );

    my $distribution =
      MetaCPAN::Document::Distribution->new( { name => $meta->name } );
    $distribution->index( $self->es );

    print "Gathering dependencies ... ";

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
    say "done";

    print "Indexing $#dependencies dependencies ... ";
    $i = 1;
    foreach my $dependencies (@dependencies) {
        print $i++;
        $dependencies = MetaCPAN::Document::Dependency->new($dependencies);
        $dependencies->index( $self->es );
        print "\010 \010" x length( $i - 1 );
    }
    say "done";

    print "Gathering modules ... ";

    # find modules
    my @modules;
    if ( keys %{ $meta->provides } && ( my $provides = $meta->provides ) ) {
        while ( my ( $module, $data ) = each %$provides ) {
            my $file = List::Util::first { $_->path eq $data->{file} } @files;
            push( @modules,
                  {  %$data,
                     name => $module,
                     file => $file,
                  } );
        }

    } elsif ( my $no_index = $meta->no_index ) {
        @files = grep { $_->{name} =~ /\.pm$/ } @files;

        foreach my $no_dir ( @{ $no_index->{directory} || [] } ) {
            @files = grep { $_->path !~ /^\Q$no_dir\E/ } @files;
        }

        foreach my $no_file ( @{ $no_index->{file} || [] } ) {
            @files = grep { $_->path !~ /^\Q$no_file\E/ } @files;
        }
        foreach my $file (@files) {
            eval {
                local $SIG{'ALRM'} =
                  sub { print "Call to Module::Metadata timed out "; die };
                alarm(5);
                my $info = Module::Metadata->new_from_file(
                                                $basedir->file( $file->path ) );
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
    foreach my $module (@modules) {
        $module = { %$module,
                    file         => $module->{file}->path,
                    file_id      => $module->{file}->id,
                    abstract     => $module->{file}->abstract,
                    release      => $release->name,
                    date         => $release->date,
                    distribution => $release->distribution,
                    author       => $release->author, };
    }

    say "done";
    print "Indexing $#modules modules ... ";
    $i = 1;
    foreach my $module (@modules) {
        print $i++;
        $module = MetaCPAN::Document::Module->new($module);
        $module->index( $self->es );
        print "\010 \010" x length( $i - 1 );
    }
    say "done";
    $dir->rmtree;
}

sub pkg_datestamp {
    my $self    = shift;
    my $archive = shift;
    my $date    = ( stat($archive) )[9];
    return DateTime::Format::Epoch::Unix->parse_datetime($date);

}

1;
