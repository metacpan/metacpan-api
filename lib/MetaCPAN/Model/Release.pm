package MetaCPAN::Model::Release;

use v5.10;
use CPAN::DistnameInfo ();
use CPAN::Meta         ();
use DateTime           ();
use File::Find         ();
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Model::Archive;
use MetaCPAN::Types qw(ArrayRef AbsFile Str);
use MetaCPAN::Util ();
use Module::Metadata 1.000012 ();    # Improved package detection.
use Moose;
use MooseX::StrictConstructor;
use Path::Class ();
use Parse::PMFile;
use Try::Tiny;

with 'MetaCPAN::Role::Logger';

has archive => (
    is      => 'ro',
    isa     => 'MetaCPAN::Model::Archive',
    lazy    => 1,
    builder => '_build_archive',
);

has dependencies => (
    is         => 'ro',
    isa        => ArrayRef,
    lazy_build => 1,
);

has distinfo => (
    is      => 'ro',
    isa     => 'CPAN::DistnameInfo',
    handles => {
        maturity     => 'maturity',
        author       => 'cpanid',
        name         => 'distvname',
        distribution => 'dist',
        filename     => 'filename',
    },
    default => sub {
        my $self = shift;
        return CPAN::DistnameInfo->new( $self->file );
    },
);

has document => (
    is         => 'ro',
    isa        => 'MetaCPAN::Document::Release',
    lazy_build => 1,
);

has file => (
    is       => 'rw',
    isa      => AbsFile,
    required => 1,
    coerce   => 1,
);

has files => (
    is         => 'ro',
    isa        => ArrayRef,
    init_arg   => undef,
    lazy_build => 1,
);

has date => (
    is      => 'rw',
    isa     => 'DateTime',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return DateTime->from_epoch( epoch => $self->file->stat->mtime );
    },
);

has index => ( is => 'rw', );

has metadata => (
    is      => 'rw',
    isa     => 'CPAN::Meta',
    lazy    => 1,
    builder => '_build_metadata',
);

has modules => (
    is      => 'ro',
    isa     => ArrayRef,
    lazy    => 1,
    default => sub {
        my $self = shift;
        if ( keys %{ $self->metadata->provides } ) {
            return $self->_modules_from_meta;
        }
        else {
            return $self->_modules_from_files;
        }
    },
);

has version => (
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    default => sub {
        my $self = shift;
        return MetaCPAN::Util::fix_version( $self->distinfo->version );
    },
);

has status => (
    is  => 'rw',
    isa => Str,
);

has bulk => ( is => 'rw', );

sub _build_archive {
    my $self = shift;

    log_info { 'Processing ', $self->file };

    my $archive = MetaCPAN::Model::Archive->new( file => $self->file );

    log_error { $self->file, ' is being impolite' } if $archive->is_impolite;

    log_error { $self->file, ' is being naughty' } if $archive->is_naughty;

    return $archive;
}

sub _build_dependencies {
    my $self = shift;
    my $meta = $self->metadata;

    log_debug {'Gathering dependencies'};

    my @dependencies;
    if ( my $prereqs = $meta->prereqs ) {
        while ( my ( $phase, $data ) = each %$prereqs ) {
            while ( my ( $relationship, $v ) = each %$data ) {
                while ( my ( $module, $version ) = each %$v ) {
                    push(
                        @dependencies,
                        Dlog_trace {"adding dependency $_"} +{
                            phase        => $phase,
                            relationship => $relationship,
                            module       => $module,
                            version      => $version,
                        }
                    );
                }
            }
        }
    }

    log_debug { 'Found ', scalar @dependencies, ' dependencies' };

    return \@dependencies;
}

sub _build_document {
    my $self = shift;

    my $st = $self->file->stat;
    my $stat = { map { $_ => $st->$_ } qw(mode uid gid size mtime) };

    my $meta         = $self->metadata;
    my $dependencies = $self->dependencies;

    my $document = DlogS_trace {"adding release $_"} +{
        abstract     => MetaCPAN::Util::strip_pod( $meta->abstract ),
        archive      => $self->filename,
        author       => $self->author,
        date         => $self->date . q{},
        dependency   => $dependencies,
        distribution => $self->distribution,

        # CPAN::Meta->license *must* be called in list context
        # (and *may* return multiple strings).
        license  => [ $meta->license ],
        maturity => $self->maturity,
        metadata => $meta,
        name     => $self->name,
        provides => [],
        stat     => $stat,
        status   => $self->status,

# Call in scalar context to make sure we only get one value (building a hash).
        ( map { ( $_ => scalar $meta->$_ ) } qw( version resources ) ),
    };

    delete $document->{abstract}
        if ( $document->{abstract} eq 'unknown'
        || $document->{abstract} eq 'null' );

    $document
        = $self->index->type('release')->put( $document, { refresh => 1 } );

    # create will die if the document already exists
    eval {
        $self->index->type('distribution')
            ->put( { name => $self->distribution }, { create => 1 } );
    };

    return $document;
}

sub _build_files {
    my $self = shift;

    my @files;
    log_debug { 'Indexing ', scalar @{ $self->archive->files }, ' files' };
    my $file_set = $self->index->type('file');

    my $extract_dir = $self->extract;
    File::Find::find(
        sub {
            my $child
                = -d $File::Find::name
                ? Path::Class::Dir->new($File::Find::name)
                : Path::Class::File->new($File::Find::name);
            return if $self->_is_broken_file($File::Find::name);
            my $relative = $child->relative($extract_dir);
            my $stat     = do {
                my $s = $child->stat;
                +{ map { $_ => $s->$_ } qw(mode uid gid size mtime) };
            };
            return if ( $relative eq q{.} );
            ( my $fpath = "$relative" ) =~ s/^.*?\///;
            my $filename = $fpath;
            $child->is_dir
                ? $filename =~ s/^(.*\/)?(.+?)\/?$/$2/
                : $filename =~ s/.*\///;
            $fpath = q{} if $relative !~ /\// && !$self->archive->is_impolite;

            my $file = $file_set->new_document(
                Dlog_trace {"adding file $_"} +{
                    author       => $self->author,
                    binary       => -B $child,
                    content_cb   => sub { \( scalar $child->slurp ) },
                    date         => $self->date,
                    directory    => $child->is_dir,
                    distribution => $self->distribution,
                    indexed      => $self->metadata->should_index_file($fpath)
                    ? 1
                    : 0,
                    local_path   => $child,
                    maturity     => $self->maturity,
                    metadata     => $self->metadata,
                    name         => $filename,
                    path         => $fpath,
                    release      => $self->name,
                    download_url => $self->document->download_url,
                    stat         => $stat,
                    status       => $self->status,
                    version      => $self->version,
                }
            );

            $self->bulk->put($file);
            push( @files, $file );
        },
        $extract_dir
    );

    $self->bulk->commit;

    return \@files;
}

my @always_no_index_dirs = (

    # Always ignore the same dirs as PAUSE (lib/PAUSE/dist.pm):
    ## skip "t" - libraries in ./t are test libraries!
    ## skip "xt" - libraries in ./xt are author test libraries!
    ## skip "inc" - libraries in ./inc are usually install libraries
    ## skip "local" - somebody shipped his carton setup!
    ## skip 'perl5" - somebody shipped her local::lib!
    ## skip 'fatlib' - somebody shipped their fatpack lib!
    qw( t xt inc local perl5 fatlib ),

    # and add a few more
    qw( example blib examples eg ),
);

sub _build_metadata {
    my $self = shift;

    my $extract_dir = $self->extract;

    return $self->_load_meta_file || CPAN::Meta->new(
        {
            license  => 'unknown',
            name     => $self->distribution,
            no_index => { directory => [@always_no_index_dirs] },
            version  => $self->version || 0,
        }
    );
}

sub _load_meta_file {
    my $self = shift;

    my $extract_dir = $self->extract;

    my @files;
    for (qw{*/META.json */META.yml */META.yaml META.json META.yml META.yaml})
    {

        # scalar context globbing (without exhausting results) produces
        # confusing results (which caused existsing */META.json files to
        # get skipped).  using list context seems more reliable.
        my ($path) = <$extract_dir/$_>;
        push( @files, $path ) if ( $path && -e $path );
    }
    return unless (@files);

    #  YAML YAML::Tiny YAML::XS don't offer better results
    my @backends = qw(CPAN::Meta::YAML YAML::Syck);
    my $error;
    while ( my $mod = shift @backends ) {
        $ENV{PERL_YAML_BACKEND} = $mod;
        my $last;
        for my $file (@files) {
            try {
                $last = CPAN::Meta->load_file($file);
            }
            catch { $error = $_ };
            if ($last) {
                last;
            }
        }
        if ($last) {
            push( @{ $last->{no_index}->{directory} },
                @always_no_index_dirs );
            return $last;
        }
    }

    log_warn {"META file could not be loaded: $error"} unless @backends;
}

sub extract {
    my $self = shift;

    log_debug {'Extracting archive to filesystem'};
    return $self->archive->extract;
}

sub _is_broken_file {
    my $self     = shift;
    my $filename = shift;

    return 1 if ( -p $filename || !-e $filename );

    if ( -l $filename ) {
        my $syml = readlink $filename;
        return 1 if ( !-e $filename && !-l $filename );
    }
    return 0;
}

sub _modules_from_meta {
    my $self = shift;

    my @modules;

    my $provides = $self->metadata->provides;
    my $files    = $self->files;
    foreach my $module ( sort keys %$provides ) {
        my $data = $provides->{$module};
        my $path = $data->{file};

        # Obey no_index and take the shortest path if multiple files match.
        my ($file) = sort { length( $a->path ) <=> length( $b->path ) }
            grep { $_->indexed && $_->path =~ /\Q$path\E$/ } @$files;

        next unless $file;
        $file->add_module(
            {
                name    => $module,
                version => $data->{version},
                indexed => 1,
            }
        );
        push( @modules, $file );
    }

    return \@modules;
}

sub _modules_from_files {
    my $self = shift;

    my @modules;

    my @perl_files = grep { $_->name =~ m{(?:\.pm|\.pm\.PL)\z} }
        grep { $_->indexed } @{ $self->files };
    foreach my $file (@perl_files) {
        if ( $file->name =~ m{\.PL\z} ) {
            my $parser = Parse::PMFile->new( $self->metadata->as_struct );

            # FIXME: Should there be a timeout on this
            # (like there is below for Module::Metadata)?
            my $info = $parser->parse( $file->local_path );
            next if !$info;

            foreach my $module_name ( keys %{$info} ) {
                $file->add_module(
                    {
                        name => $module_name,
                        defined $info->{$module_name}->{version}
                        ? ( version => $info->{$module_name}->{version} )
                        : (),
                    }
                );
            }
            push @modules, $file;
        }
        else {
            eval {
                local $SIG{'ALRM'} = sub {
                    log_error {'Call to Module::Metadata timed out '};
                    die;
                };
                alarm(5);
                my $info;
                {
                    local $SIG{__WARN__} = sub { };
                    $info = Module::Metadata->new_from_file(
                        $file->local_path );
                }

          # Ignore packages that people cannot claim.
          # https://github.com/andk/pause/blob/master/lib/PAUSE/pmfile.pm#L236
                for my $pkg ( grep { $_ ne 'main' && $_ ne 'DB' }
                    $info->packages_inside )
                {
                    my $version = $info->version($pkg);
                    $file->add_module(
                        {
                            name => $pkg,
                            defined $version

# Stringify if it's a version object, otherwise fall back to stupid stringification
# Changes in Module::Metadata were causing inconsistencies in the return value,
# we are just trying to survive.
                            ? (
                                version => ref $version eq 'version'
                                ? $version->stringify
                                : ( $version . q{} )
                                )
                            : ()
                        }
                    );
                }
                push( @modules, $file );
                alarm(0);
            };
        }
    }

    return \@modules;
}

__PACKAGE__->meta->make_immutable();
1;
