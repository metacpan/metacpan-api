package MetaCPAN::Script::Release;

use strict;
use warnings;

BEGIN {
    $ENV{PERL_JSON_BACKEND} = 'JSON::XS';
}

use CPAN::DistnameInfo ();
use CPAN::Meta         ();
use DateTime           ();
use File::Find         ();
use File::Find::Rule;
use File::Temp ();
use File::stat ();
use LWP::UserAgent;
use List::MoreUtils ();
use List::Util      ();
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Document::Author;
use MetaCPAN::Script::Latest;
use Module::Metadata 1.000012 ();    # Improved package detection.
use Moose;
use Parse::PMFile;
use Path::Class qw(file dir);
use PerlIO::gzip;
use Try::Tiny;

with 'MetaCPAN::Role::Common', 'MooseX::Getopt';

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
            log_info {"Looking for tarballs in $_"};
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
    log_info { scalar @files, " tarballs found" } if ( @files > 1 );

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
                {   and => [
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
            try { $self->import_tarball($file) }
            catch {
                log_fatal {$_};
            };
            exit if ( $self->children );
        }
    }
    waitpid( -1, 0 ) for (@pid);
    $self->index->refresh;
}

sub import_tarball {
    my ( $self, $tarball ) = @_;
    my $cpan = $self->index;

    $tarball = Path::Class::File->new($tarball);
    my $d = CPAN::DistnameInfo->new($tarball);
    my ( $author, $archive, $name )
        = ( $d->cpanid, $d->filename, $d->distvname );
    log_info {"Processing $tarball"};

    # load Archive::Any in the child due to bugs in MMagic and MIME::Types
    require Archive::Any;
    my $at = Archive::Any->new($tarball);
    my $tmpdir = dir( File::Temp::tempdir( CLEANUP => 0 ) );

    log_error {"$tarball is being impolite"} if $at->is_impolite;

    # TODO: add release to the index with status => 'broken' and move along
    log_error {"$tarball is being naughty"} if $at->is_naughty;

    log_debug {"Extracting archive to filesystem"};
    $at->extract($tmpdir);

    my $date    = DateTime->from_epoch( epoch => $tarball->stat->mtime );
    my $version = MetaCPAN::Util::fix_version( $d->version );
    my $meta    = CPAN::Meta->new(
        {   version => $version || 0,
            license => 'unknown',
            name    => $d->dist,
            no_index =>
                { directory => [qw(t xt inc example blib examples eg)] }
        }
    );

    my $st = $tarball->stat;
    my $stat = { map { $_ => $st->$_ } qw(mode uid gid size mtime) };

    $meta = $self->load_meta_file($tmpdir) || $meta;

    log_debug {'Gathering dependencies'};

    my @dependencies = $self->dependencies($meta);

    log_debug { 'Found ', scalar @dependencies, " dependencies" };

    my $release = DlogS_trace {"adding release $_"} +{
        abstract     => MetaCPAN::Util::strip_pod( $meta->abstract ),
        name         => $name,
        author       => $author,
        distribution => $d->dist,
        archive      => $archive,
        maturity     => $d->maturity,
        stat         => $stat,
        status       => $self->detect_status( $author, $archive ),
        date         => $date . q{},
        dependency   => \@dependencies,
        metadata     => $meta,
        provides     => [],

        # CPAN::Meta->license *must* be called in list context
        # (and *may* return multiple strings).
        license => [ $meta->license ],

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

    my @files;
    my @list = $at->files;
    log_debug { 'Indexing ', scalar @files, " files" };
    my $file_set = $cpan->type('file');
    my $bulk = $cpan->bulk( size => 10 );

    File::Find::find(
        sub {
            my $child
                = -d $File::Find::name
                ? dir($File::Find::name)
                : file($File::Find::name);
            my $relative = $child->relative($tmpdir);
            my $stat     = do {
                my $s = $child->stat;
                +{ map { $_ => $s->$_ } qw(mode uid gid size mtime) };
            };
            return if ( $relative eq '.' );
            ( my $fpath = "$relative" ) =~ s/^.*?\///;
            my $fname = $fpath;
            $child->is_dir
                ? $fname =~ s/^(.*\/)?(.+?)\/?$/$2/
                : $fname =~ s/.*\///;
            $fpath = "" if $relative !~ /\// && !$at->is_impolite;

            my $file = $file_set->new_document(
                Dlog_trace {"adding file $_"} +{
                    metadata     => $meta,
                    name         => $fname,
                    directory    => $child->is_dir,
                    release      => $name,
                    date         => $date,
                    distribution => $d->dist,
                    author       => $author,
                    local_path   => $child,
                    path         => $fpath,
                    version      => $d->version,
                    stat         => $stat,
                    maturity     => $d->maturity,
                    status       => $release->status,
                    indexed      => $meta->should_index_file($fpath) ? 1 : 0,
                    binary       => -B $child,
                    content_cb => sub { \( scalar $child->slurp ) },
                }
            );
            $bulk->put($file);
            push( @files, $file );
        },
        $tmpdir
    );
    $bulk->commit;

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
        while ( my ( $module, $data ) = each %provides ) {
            my $path = $data->{file};

            # FIXME: Could this match lib/Foo.pm and eg/lib/Foo.pm?
            my $file = List::Util::first { $_->path =~ /\Q$path\E$/ } @files;
            next unless $file;
            $file->add_module(
                {   name    => $module,
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
                        {   name => $module_name,
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
                    for my $pkg ( grep { $_ ne 'main' }
                        $info->packages_inside )
                    {
                        my $version = $info->version($pkg);
                        $file->add_module(
                            {   name => $pkg,
                                defined $version

                    # Stringify if it's an object (and don't die if it's not).
                                ? ( version => $version . '' )
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
        $release->provides( \@provides );
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

    $tmpdir->rmtree;

    if ( $self->latest ) {
        local @ARGV = ( qw(latest --distribution), $release->distribution );
        MetaCPAN::Script::Runner->run;
    }
}

sub load_meta_file {
    my ( $self, $dir ) = @_;
    my @files;
    for (qw{*/META.json */META.yml */META.yaml META.json META.yml META.yaml})
    {

        # scalar context globbing (without exhausting results) produces
        # confusing results (which caused existsing */META.json files to
        # get skipped).  using list context seems more reliable.
        my ($path) = <$dir/$_>;
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
            push(
                @{ $last->{no_index}->{directory} },
                qw(t xt inc example blib examples eg)
            );
            return $last;
        }
    }

    log_warn {"META file could not be loaded: $error"}
    unless (@backends);
}

sub dependencies {
    my ( $self, $meta ) = @_;
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
    return @dependencies;
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
a file. If the tarball cannot be find in the cpan mirror, it tries the temporary
folder. After a rsync this folder can be purged.

=cut
