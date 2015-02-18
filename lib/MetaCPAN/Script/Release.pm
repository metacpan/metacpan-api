package MetaCPAN::Script::Release;

use strict;
use warnings;

BEGIN {
    $ENV{PERL_JSON_BACKEND} = 'JSON::XS';
}

use CPAN::DistnameInfo ();
use DateTime           ();
use File::Find::Rule;
use File::stat ();
use LWP::UserAgent;
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Document::Author;
use MetaCPAN::Script::Latest;
use MetaCPAN::Model::Release;
use MetaCPAN::Types qw( Dir );
use Module::Metadata 1.000012 ();    # Improved package detection.
use Moose;
use Parse::PMFile;
use Path::Class qw(file dir);
use PerlIO::gzip;
use Try::Tiny;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has latest => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => q{run 'latest' script after each release},
);

has age => (
    is            => 'ro',
    isa           => 'Int',
    documentation => 'index releases no older than x hours (undef)',
);

has children => (
    is            => 'ro',
    isa           => 'Int',
    default       => 2,
    documentation => 'number of worker processes (2)',
);

has skip => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'skip already indexed modules (0)',
);

has status => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'cpan',
    documentation => 'status of the indexed releases (cpan)',
);

has detect_backpan => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'enable when indexing from a backpan',
);

has backpan_index => (
    is         => 'ro',
    lazy_build => 1,
);

has perms => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
    traits     => ['NoGetopt'],
);

sub run {
    my $self = shift;
    my ( undef, @args ) = @{ $self->extra_argv };
    my @files;
    for (@args) {
        if ( -d $_ ) {
            log_info {"Looking for archives in $_"};
            my $find = File::Find::Rule->new->file->name(
                qr/\.(tgz|tbz|tar[\._-]gz|tar\.bz2|tar\.Z|zip|7z)$/);
            $find = $find->mtime( ">" . ( time - $self->age * 3600 ) )
                if ( $self->age );
            push(
                @files,
                map { $_->{file} } sort { $a->{mtime} <=> $b->{mtime} } map {
                    +{ file => $_, mtime => File::stat::stat($_)->mtime }
                } $find->in($_)
            );
        }
        elsif ( -f $_ ) {
            push( @files, $_ );
        }
        elsif ( $_ =~ /^https?:\/\// && CPAN::DistnameInfo->new($_)->cpanid )
        {
            my $d    = CPAN::DistnameInfo->new($_);
            my $file = $self->home->file(
                qw(var tmp http authors),
                MetaCPAN::Document::Author::_build_dir( $d->cpanid ),
                $d->filename,
            );
            my $ua = LWP::UserAgent->new(
                parse_head => 0,
                env_proxy  => 1,
                agent      => 'metacpan',
                timeout    => 30,
            );
            $file->dir->mkpath;
            log_info {"Downloading $_"};
            $ua->mirror( $_, $file );
            if ( -e $file ) {
                push( @files, $file );
            }
            else {
                log_error {"Downloading $_ failed"};
            }
        }
        else {
            log_error {"Dunno what $_ is"};
        }
    }
    log_info { scalar @files, " archives found" } if ( @files > 1 );

    # build here before we fork
    $self->index;
    $self->backpan_index if ( $self->detect_backpan );
    $self->perms;
    my @pid;

    # FIXME: What is this supposed to do?  Don't do 'my' in a condition.
    my $cpan = $self->index if ( $self->skip );
    eval { DB::enable_profile() };
    while ( my $file = shift @files ) {

        if ( $self->skip ) {
            my $d     = CPAN::DistnameInfo->new($file);
            my $count = $cpan->type('release')->filter(
                {
                    and => [
                        { term => { archive => $d->filename } },
                        { term => { author  => $d->cpanid } },
                    ]
                }
            )->inflate(0)->count;
            if ($count) {
                log_info {"Skipping $file"};
                next;
            }
        }

        if ( @pid >= $self->children ) {
            my $pid = waitpid( -1, 0 );
            @pid = grep { $_ != $pid } @pid;
        }
        if ( $self->children && ( my $pid = fork() ) ) {
            push( @pid, $pid );
        }
        else {
            try { $self->import_archive($file) }
            catch {
                log_fatal {$_};
            };
            exit if ( $self->children );
        }
    }
    waitpid( -1, 0 ) for (@pid);
    $self->index->refresh;
}

sub import_archive {
    my $self         = shift;
    my $archive_path = Path::Class::File->new(shift);

    my $cpan = $self->index;
    my $d    = CPAN::DistnameInfo->new($archive_path);
    my ( $author, $archive, $name )
        = ( $d->cpanid, $d->filename, $d->distvname );
    my $date    = DateTime->from_epoch( epoch => $archive_path->stat->mtime );
    my $version = MetaCPAN::Util::fix_version( $d->version );
    my $bulk    = $cpan->bulk( size => 10 );

    my $release_model = MetaCPAN::Model::Release->new(
        author       => $author,
        bulk         => $bulk,
        date         => $date,
        distribution => $d->dist,
        file         => $archive_path,
        index        => $cpan,
        level        => $self->level,
        logger       => $self->logger,
        maturity     => $d->maturity,
        name         => $name,
        status       => $self->detect_status( $author, $archive ),
        version      => $d->version,
    );

    my $st = $archive_path->stat;
    my $stat = { map { $_ => $st->$_ } qw(mode uid gid size mtime) };

    my $meta         = $release_model->metadata;
    my $dependencies = $release_model->dependencies;

    my $release = DlogS_trace {"adding release $_"} +{
        abstract     => MetaCPAN::Util::strip_pod( $meta->abstract ),
        archive      => $archive,
        author       => $author,
        date         => $date . q{},
        dependency   => $dependencies,
        distribution => $d->dist,

        # CPAN::Meta->license *must* be called in list context
        # (and *may* return multiple strings).
        license  => [ $meta->license ],
        maturity => $d->maturity,
        metadata => $meta,
        name     => $name,
        provides => [],
        stat     => $stat,
        status   => $release_model->status,

# Call in scalar context to make sure we only get one value (building a hash).
        ( map { ( $_ => scalar $meta->$_ ) } qw( version resources ) ),
    };

    delete $release->{abstract}
        if ( $release->{abstract} eq 'unknown'
        || $release->{abstract} eq 'null' );

    $release = $cpan->type('release')->put( $release, { refresh => 1 } );

    # create will die if the document already exists
    eval {
        $cpan->type('distribution')
            ->put( { name => $d->dist }, { create => 1 } );
    };

    my @files = $release_model->get_files();

    log_debug {'Gathering modules'};

    # build module -> pod file mapping
    # $file->clear_documentation to force a rebuild
    my %associated_pod;
    for ( grep { $_->indexed && $_->documentation } @files ) {
        my $documentation = $_->clear_documentation;
        $associated_pod{$documentation}
            = [ @{ $associated_pod{$documentation} || [] }, $_ ];
    }

    # find modules
    my @modules;

    if ( my %provides = %{ $meta->provides } ) {
        foreach my $module ( sort keys %provides ) {
            my $data = $provides{$module};
            my $path = $data->{file};

           # Obey no_index and take the shortest path if multiple files match.
            my ($file) = sort { length( $a->path ) <=> length( $b->path ) }
                grep { $_->indexed && $_->path =~ /\Q$path\E$/ } @files;

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
    }
    else {
        @files = grep { $_->name =~ m{(?:\.pm|\.pm\.PL)\z} }
            grep { $_->indexed } @files;
        foreach my $file (@files) {

            if ( $file->name =~ m{\.PL\z} ) {

                my $parser = Parse::PMFile->new( $meta->as_struct );

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
                                    version => ref $version eq "version"
                                    ? $version->stringify
                                    : ( $version . '' )
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
    }
    log_debug { 'Indexing ', scalar @modules, ' modules' };
    my $perms = $self->perms;
    my @release_unauthorized;
    my @provides;
    foreach my $file (@modules) {
        $_->set_associated_pod( $file, \%associated_pod )
            for ( @{ $file->module } );
        $file->set_indexed($meta);

     # NOTE: "The method returns a list of unauthorized, but indexed modules."
        push( @release_unauthorized, $file->set_authorized($perms) )
            if ( keys %$perms );

        for ( @{ $file->module } ) {
            push( @provides, $_->name ) if $_->indexed && $_->authorized;
        }
        $file->clear_module if ( $file->is_pod_file );
        log_trace {"reindexing file $file->{path}"};
        $bulk->put($file);
        if ( !$release->has_abstract && $file->abstract ) {
            ( my $module = $release->distribution ) =~ s/-/::/g;
            $release->abstract( $file->abstract );
            $release->put;
        }
    }
    if (@provides) {
        $release->provides( [ sort @provides ] );
        $release->put;
    }
    $bulk->commit;

    if (@release_unauthorized) {
        log_info {
            "release "
                . $release->name
                . " contains unauthorized modules: "
                . join( ",", map { $_->name } @release_unauthorized );
        };
        $release->authorized(0);
        $release->put;
    }

    if ( $self->latest ) {
        local @ARGV = ( qw(latest --distribution), $release->distribution );
        MetaCPAN::Script::Runner->run;
    }
}

sub _build_backpan_index {
    my $self = shift;
    my $ls   = $self->cpan->file(qw(indices find-ls.gz));
    unless ( -e $ls ) {
        log_error {"File $ls does not exist"};
        exit;
    }
    log_info {"Reading $ls"};
    my $cpan = {};
    open my $fh, "<:gzip", $ls;
    while (<$fh>) {
        my $path = ( split(/\s+/) )[-1];
        next unless ( $path =~ /^authors\/id\/\w+\/\w+\/(.*)$/ );
        $cpan->{$1} = 1;
    }
    close $fh;
    return $cpan;
}

sub detect_status {
    my ( $self, $author, $archive ) = @_;
    return $self->status unless ( $self->detect_backpan );
    if ( $self->backpan_index->{ join( '/', $author, $archive ) } ) {
        return 'cpan';
    }
    else {
        log_debug {'BackPAN detected'};
        return 'backpan';
    }
}

sub _build_perms {
    my $self = shift;
    my $file = $self->cpan->file(qw(modules 06perms.txt));
    my %authors;
    if ( -e $file ) {
        log_debug { "parsing ", $file };
        my $fh = $file->openr;
        while ( my $line = <$fh> ) {
            my ( $module, $author, $type ) = split( /,/, $line );
            next unless ($type);
            $authors{$module} ||= [];
            push( @{ $authors{$module} }, $author );
        }
        close $fh;
    }
    else {
        log_warn {"$file could not be found."};
    }

    my $packages = $self->cpan->file(qw(modules 02packages.details.txt.gz));
    if ( -e $packages ) {
        log_debug { "parsing ", $packages };
        open my $fh, "<:gzip", $packages;
        while ( my $line = <$fh> ) {
            if ( $line =~ /^(.+?)\s+.+?\s+\S\/\S+\/(\S+)\// ) {
                $authors{$1} ||= [];
                push( @{ $authors{$1} }, $2 );
            }
        }
        close $fh;
    }
    return \%authors;
}

$SIG{__WARN__} = sub {
    my $msg = shift;
    warn $msg unless $msg =~ m{Invalid header block at offset unknown at};
};

__PACKAGE__->meta->make_immutable;
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
a file. If the archive cannot be find in the cpan mirror, it tries the temporary
folder. After a rsync this folder can be purged.

=cut
