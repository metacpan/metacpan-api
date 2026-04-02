package MetaCPAN::Server::Model::Source;
use strict;
use warnings;

use Archive::Libarchive 0.04 qw(
    ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS
    ARCHIVE_EXTRACT_SECURE_NODOTDOT
    ARCHIVE_EXTRACT_SECURE_SYMLINKS
    ARCHIVE_EXTRACT_TIME
);
use Archive::Libarchive::DiskWrite ();
use Archive::Libarchive::Extract   ();
use MetaCPAN::Types                qw( Path Uri );
use MetaCPAN::Util                 ();
use Moose;
use Path::Tiny ();

extends 'Catalyst::Model';

has source_dir => (
    is      => 'ro',
    isa     => Path,
    coerce  => 1,
    default => 'var/tmp/source',
);

has cpan => (
    is     => 'ro',
    isa    => Path,
    coerce => 1,
);

has remote_cpan => (
    is     => 'ro',
    isa    => Uri,
    coerce => 1,
);

has es_query => (
    is     => 'ro',
    writer => '_set_es_query',
);

has http_cache_dir => (
    is      => 'ro',
    isa     => Path,
    coerce  => 1,
    default => 'var/tmp/http',
);

has ua => (
    is      => 'ro',
    default => sub {
        LWP::UserAgent->new( agent => 'metacpan-api/1.0', );
    },
);

sub COMPONENT {
    my $self = shift;
    my ( $app, $config ) = @_;
    my $app_config = $app->config;

    $config = $self->merge_config_hashes(
        {
            ( $app_config->{cpan} ? ( cpan => $app_config->{cpan} ) : () ),
            (
                $app_config->{source_dir}
                ? ( source_dir => $app_config->{source_dir} )
                : ()
            ),
            (
                $app_config->{remote_cpan}
                ? ( remote_cpan => $app_config->{remote_cpan} )
                : ()
            ),
        },
        $config,
    );
    return $self->SUPER::COMPONENT( $app, $config );
}

sub ACCEPT_CONTEXT {
    my ( $self, $c ) = @_;
    if ( !$self->es_query ) {
        $self->_set_es_query( $c->model('ESQuery') );
    }
    return $self;
}

sub path {
    my ( $self, $pauseid, $distvname, @file ) = @_;
    my $base        = $self->source_dir;
    my $source_base = Path::Tiny::path( $base, $pauseid, $distvname );
    my $source      = $source_base->child( $distvname, @file );
    return $source
        if -e $source;

    # if the directory exists, we already extracted the archive, so if the
    # file didn't exist, we can stop here
    return undef
        if -e $source_base->child($distvname);

    my $release_data
        = $self->es_query->release->by_author_and_name( $pauseid, $distvname )
        ->{release}
        or return undef;

    my $author_path = MetaCPAN::Util::author_dir($pauseid);

    my $http_author_dir
        = $self->http_cache_dir->child( 'authors', $author_path );

    my $local_cpan = $self->cpan;
    my $cpan_author_dir
        = $local_cpan && $local_cpan->child( 'authors', $author_path );

    my $archive = $release_data->{archive};
    my ($local_archive)
        = grep -e,
        map $_->child($archive),
        grep defined,
        ( $cpan_author_dir, $http_author_dir );

    if ( !$local_archive ) {
        $local_archive = $http_author_dir->child($archive);
        $self->fetch_from_cpan( $release_data->{download_url},
            $local_archive )
            or return undef;
    }
    my $extracted
        = $self->extract_in( $local_archive, $source_base, $distvname );

    return undef
        if !-e $source;

    return $source;
}

# Archive::Libarchive::Extract doesn't allow setting the options for writing
# to disk, which includes very useful options like
# ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS and ARCHIVE_EXTRACT_SECURE_NODOTDOT,
# A PR has been filed to add this: https://github.com/uperl/Archive-Libarchive-Extract/pull/7
our $OVERRIDE_DISK_SET_OPTIONS;
{
    my $disk_set_options = \&Archive::Libarchive::DiskWrite::disk_set_options;
    no warnings 'redefine';
    *Archive::Libarchive::DiskWrite::disk_set_options = sub {
        my ( $dw, $flags ) = @_;
        if ( defined $OVERRIDE_DISK_SET_OPTIONS ) {
            $flags = $OVERRIDE_DISK_SET_OPTIONS;
        }
        $dw->$disk_set_options($flags);
    };
}

sub extract_in {
    my ( $self, $archive_file, $base, $child_name ) = @_;

    my $final_dir = $base->child($child_name);

    $base->mkpath;

    my $temp = Path::Tiny->tempdir(
        TEMPLATE => 'cpan-extract-XXXXXXX',
        TMPDIR   => 0,
        DIR      => $base->stringify,
        CLEANUP  => 0,
    );

    eval {
        local $OVERRIDE_DISK_SET_OPTIONS
            = ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS
            | ARCHIVE_EXTRACT_SECURE_NODOTDOT
            | ARCHIVE_EXTRACT_SECURE_SYMLINKS;
        my $archive
            = Archive::Libarchive::Extract->new( filename => $archive_file );
        $archive->extract( to => $temp );
        1;
    } or do {
        warn "extracting $archive_file: $@";
        return;
    };

    my @children = $temp->children;

    my $extract_dir;
    if ( @children == 1 && -d $children[0] ) {
        $extract_dir = $children[0];
    }
    else {
        $extract_dir = $temp;
    }

    rename $children[0], $final_dir or do {
        warn "can't move $children[0] to $final_dir: $!";
    };
    $temp->remove_tree;

    return $final_dir;
}

sub fetch_from_cpan {
    my ( $self, $download_url, $local_archive ) = @_;
    $local_archive->parent->mkpath;

    if ( my $remote_cpan = $self->remote_cpan ) {
        $remote_cpan =~ s{/\z}{};
        $download_url
            =~ s{\Ahttps?://(?:(?:backpan|cpan)\.metacpan\.org|(?:backpan\.|www\.)?cpan\.org|backpan\.cpantesters\.org)/}{$remote_cpan/};
    }

    my $ua       = $self->ua;
    my $response = $ua->mirror( $download_url, $local_archive );
    return $response->is_success;
}

__PACKAGE__->meta->make_immutable;
1;
