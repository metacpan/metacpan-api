package MetaCPAN::Script::Release;
use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';
use Log::Contextual qw( :log :dlog );

use Path::Class qw(file dir);
use File::Temp         ();
use CPAN::Meta         ();
use DateTime           ();
use List::Util         ();
use List::MoreUtils    ();
use Module::Metadata   ();
use File::stat         ('stat');
use CPAN::DistnameInfo ();
use File::Spec::Functions ('tmpdir', 'catdir');
use MetaCPAN::Script::Latest;
use DateTime::Format::Epoch::Unix;
use File::Find::Rule;
use Try::Tiny;
use LWP::UserAgent;
use MetaCPAN::Document::Author;

has latest  => ( is => 'ro', isa => 'Bool', default => 0 );
has age     => ( is => 'ro', isa => 'Int' );
has children  => ( is => 'ro', isa => 'Int', default => 2 );
has skip    => ( is => 'ro', isa => 'Bool', default => 0 );

sub run {
    my $self = shift;
    my ( undef, @args ) = @{ $self->extra_argv };
    my @files;
    for (@args) {
        if ( -d $_ ) {
            log_info { "Looking for tarballs in $_" };
            my $find = File::Find::Rule->new->file->name(
                qr/\.(tgz|tbz|tar[\._-]gz|tar\.bz2|tar\.Z|zip|7z)$/
            );
            $find = $find->mtime( ">" . ( time - $self->age * 3600 ) )
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
                                      ),
                                      $d->filename );
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
    my @pid;
    my $cpan = $self->index if($self->skip);
    while ( my $file = shift @files ) {
        
        if($self->skip) {
            my $d    = CPAN::DistnameInfo->new($file);
            my ( $author, $archive, $name ) =
              ( $d->cpanid, $d->filename, $d->distvname );

            my $count = $cpan->type('release')->query(
            { query => { filtered => { query  => { match_all => {} },
              filter => {
                and => [
                    { term => { archive => $archive } },
                    { term => { author  => $author } } ]
            } } } } )->inflate(0)->count;
            if($count) {
                log_info { "Skipping $file" };
                next;
            }
        }
        
        if(@pid >= $self->children) {
            my $pid = waitpid( -1, 0);
            @pid = grep { $_ != $pid } @pid;
        }
        if($self->children && (my $pid = fork())) {
            push(@pid, $pid);
        } else {
                try { $self->import_tarball($file) }
                catch {
                    log_fatal { $_ };
                };
                exit if($self->children);
        };
    }
    waitpid( -1, 0) for(@pid);
    $self->model->es->refresh_index( index => 'cpan' );
}

sub import_tarball {
    my ( $self, $tarball ) = @_;
    my $cpan = $self->index;

    $tarball = Path::Class::File->new($tarball);
    my $d    = CPAN::DistnameInfo->new($tarball);
    my ( $author, $archive, $name ) =
      ( $d->cpanid, $d->filename, $d->distvname );

    log_info { "Processing $tarball" };
    
    # load Archive::Any in the child due to bugs in MMagic and MIME::Types
    require Archive::Any;
    my $at = Archive::Any->new($tarball);
    my $tmpdir = dir(File::Temp::tempdir(CLEANUP => 1));

    # TODO: add release to the index with status => 'broken' and move along
    log_error { "$tarball is being naughty" }
     if $at->is_naughty || $at->is_impolite;

    log_debug { "Extracting archive to filesystem" };
    $at->extract($tmpdir);

    my $date = $self->pkg_datestamp($tarball);
    my $version = MetaCPAN::Util::fix_version( $d->version );
    my $meta = CPAN::Meta->new(
                                { version => $version || 0,
                                  license => 'unknown',
                                  name    => $d->dist,
                                  no_index => { directory => [qw(t xt inc)] } }
    );

    my @files;
    my $meta_file;
    log_debug { "Gathering files" };
    my @list = $at->files;
    $tmpdir->recurse(callback => sub {
        my $child = shift;
        my $relative = $child->relative($tmpdir);
        $meta_file = $relative if ( !$meta_file && $relative =~ /^[^\/]+\/META\./ || $relative =~ /^[^\/]+\/META\.json/ );
        my $stat = do {
            my $s = $child->stat;
            +{ map { $_ => $s->$_ } qw(mode uid gid size mtime) };
        };
        return if ( $relative eq '.' );
        ( my $fpath = "$relative" ) =~ s/^.*?\///;
        my $fname = $fpath;
        $child->is_dir
          ? $fname =~ s/^(.*\/)?(.+?)\/?$/$2/
          : $fname =~ s/.*\///;
        $fpath = "" unless($relative =~ /\//);
        warn $fpath if($child->is_dir);
        push(
            @files,
            Dlog_trace { "adding file $_" } +{
                name         => $fname,
                directory    => $child->is_dir,
                release      => $name,
                date         => $date,
                distribution => $d->dist,
                author       => $author,
                full_path    => $child,
                path         => $fpath,
                version      => $d->version,
                stat         => $stat,
                maturity     => $d->maturity,
                indexed      => 1,
                content_cb   => sub { \( scalar $child->slurp ) },
            } );
    });
    $meta = $self->load_meta_file($meta, $tmpdir->file($meta_file))
        if($meta_file);

    push( @{ $meta->{no_index}->{directory} }, qw(t xt inc example examples eg) );
    map { $_->{indexed} = 0 } grep { !$meta->should_index_file($_->{path}) } @files;

    log_debug { "Indexing ", scalar @files, " files" };
    my $i = 1;
    my $file_set = $cpan->type('file');
    foreach my $file (@files) {
        my $obj = $file_set->put($file);
        $file->{$_} = $obj->$_ for(qw(abstract id pod sloc pod_lines));
        $file->{module}   = [];
    }

    log_debug { "Gathering dependencies" };

    # find dependencies
    my @dependencies;
    if ( my $prereqs = $meta->prereqs ) {
        while ( my ( $phase, $data ) = each %$prereqs ) {
            while ( my ( $relationship, $v ) = each %$data ) {
                while ( my ( $module, $version ) = each %$v ) {
                    push( @dependencies,
                          Dlog_trace { "adding dependency $_" }
                          +{  phase        => $phase,
                              relationship => $relationship,
                              module       => $module,
                              version      => $version,
                          } );
                }
            }
        }
    }

    log_debug { "Found ", scalar @dependencies, " dependencies" };

    my $st = stat($tarball);
    my $stat = { map { $_ => $st->$_ } qw(mode uid gid size mtime) };
    my $create = DlogS_trace { "adding release $_" }
    +{  %{$meta->as_struct},
        name         => $name,
        author       => $author,
        distribution => $d->dist,
        archive      => $archive,
        maturity     => $d->maturity,
        stat         => $stat,
        date         => $date,
        dependency   => \@dependencies };
    $create->{abstract} = MetaCPAN::Util::strip_pod($create->{abstract});
    delete $create->{abstract}
        if($create->{abstract} eq 'unknown' || $create->{abstract} eq 'null');

    my $release = $cpan->type('release')->put($create);

    log_debug { "Gathering modules" };

    # find modules
    my @modules;
    if ( keys %{ $meta->provides } && ( my $provides = $meta->provides ) ) {
        while ( my ( $module, $data ) = each %$provides ) {
            my $path = $data->{file};
            my $file = List::Util::first { $_->{path} =~ /\Q$path\E$/ } @files;
            push(@{$file->{module}}, { name => $module, version => $data->{version} });
            push(@modules, $file);
        }
    } else {
        @files = grep { $_->{name} =~ /\.pm$/ } grep { $_->{indexed} } @files;
        foreach my $file (@files) {
            eval {
                local $SIG{'ALRM'} = sub {
                    log_error { "Call to Module::Metadata timed out " };
                    die;
                };
                alarm(5);
                my $info;
                {
                    local $SIG{__WARN__} = sub { };
                    $info = Module::Metadata->new_from_file(
                                              $tmpdir->file( $file->{full_path} ) );
                }
                push(@{$file->{module}}, { name => $_, 
                      $info->version
                         ? ( version => $info->version->numify )
                         : () }) for ( grep { $_ ne 'main' } $info->packages_inside );
                push(@modules, $file);
                alarm(0);
            };
        }
    }
    log_debug { "Indexing ", scalar @modules, " modules" };
    $i = 1;
    my $mod_set = $cpan->type('module');
    foreach my $file (@modules) {
        $file = MetaCPAN::Document::File->new( %$file, index => $cpan );
        foreach my $mod ( @{ $file->module } ) {
            $mod->indexed(   $meta->should_index_package( $mod->name )
                           ? $mod->hide_from_pause( ${ $file->content } )
                                 ? 0
                                 : 1
                           : 0 );
        }
        $file->indexed(!!grep { $file->documentation eq $_->name } @{$file->module})
            if($file->documentation);
        log_trace { "reindexing file $file->{path}" };
        Dlog_trace { $_ } $file->meta->get_data($file);
        $file->clear_module if($file->is_pod_file);
        $file->put;
    }

    $tmpdir->rmtree;

    if ( $self->latest ) {
        local @ARGV = ( qw(latest --distribution), $release->distribution );
        MetaCPAN::Script::Runner->run;
    }
}

sub pkg_datestamp {
    my $self    = shift;
    my $archive = shift;
    my $date    = stat($archive)->mtime;
    return DateTime::Format::Epoch::Unix->parse_datetime($date);

}

sub load_meta_file {
    my ($self, $meta, $meta_file) = @_;
    #  YAML YAML::Tiny YAML::XS don't offer better results
    my @backends = qw(CPAN::Meta::YAML YAML::Syck);

    while(my $mod = shift @backends) {
        $ENV{PERL_YAML_BACKEND} = $mod;
        my $last;
        try {
            $last =
              CPAN::Meta->load_file( $meta_file );
        };
        return $last if($last);
    }

    log_warn { "META file could not be loaded: $_" }
        unless(@backends);
    return $meta;
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
