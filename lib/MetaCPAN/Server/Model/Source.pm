package MetaCPAN::Server::Model::Source;
use strict;
use warnings;

use Archive::Any              ();
use MetaCPAN::Types::TypeTiny qw( Path Uri );
use MetaCPAN::Util            ();
use Moose;
use Path::Tiny ();

extends 'Catalyst::Model';

has base_dir => (
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
                $app_config->{base_dir}
                ? ( base_dir => $app_config->{base_dir} )
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
    my $base        = $self->base_dir;
    my $source_base = Path::Tiny::path( $base, $pauseid, $distvname );
    my $source      = $source_base->child( $distvname, @file );
    return $source
        if -e $source;
    return undef
        if -e $source_base->child($distvname);    # previously extracted, but file does not exist

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

sub extract_in {
    my ( $self, $archive_file, $base, $child_name ) = @_;

    my $archive = Archive::Any->new($archive_file);

    return undef
        if $archive->is_naughty;

    my $extract_root = $base;
    my $extract_dir  = $base->child($child_name);

    if ( $archive->is_impolite ) {
        $extract_root = $extract_dir;
    }

    $extract_root->mkpath;
    $archive->extract($extract_root);

    my @children = $extract_root->children;
    if ( @children == 1 && -d $children[0] ) {

        # one directory, but with wrong name
        if ( $children[0]->basename ne $child_name ) {
            $children[0]->move($extract_dir);
        }
    }
    else {
        my $temp = Path::Tiny->tempdir(
            TEMPLATE => 'cpan-extract-XXXXXXX',
            TMPDIR   => 0,
            DIR      => $extract_root,
            CLEANUP  => 0,
        );

        for my $child (@children) {
            $child->move($temp);
        }

        $temp->move($extract_dir);
    }

    return $extract_dir;
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
