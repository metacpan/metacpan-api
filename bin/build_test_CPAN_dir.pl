#!/usr/bin/env perl

# Script to create a /tmp/CPAN/ directory with a 02packages.details.txt.gz file
# To use as a basic for the ElasticSearch index and CPAN-API testing
# and development on the development virtual machine

use strict;
use warnings;
use ElasticSearch;
use LWP::Simple qw(mirror is_success is_redirect);
use OrePAN2 0.07;
use OrePAN2::Injector;
use OrePAN2::Indexer;
use feature qw( say );

my $OUT_DIR  = '/tmp/tmp_tar_files/';
my $CPAN_DIR = '/tmp/CPAN/';

my $modules_to_fetch = {
    'Data::Pageset' => '1.06',
    'ElasticSearch' => '0.65',
};

my $injector = OrePAN2::Injector->new( directory => $CPAN_DIR, );

my $es = ElasticSearch->new(
    no_refresh => 1,
    servers    => 'fastapi.metacpan.org',

    # trace_calls => \*STDOUT,
);

my %seen;
foreach my $module_name ( keys %{$modules_to_fetch} ) {
    my $version = $modules_to_fetch->{$module_name};

    _download_with_dependencies( $module_name, $version );
}

# build the 02packages.details.txt.gz file
OrePAN2::Indexer->new( directory => $CPAN_DIR )->make_index();

sub _download_with_dependencies {
    my ( $module_name, $version ) = @_;

    my $seen_key = $module_name . $version;
    return if $seen{$seen_key};

    my ( $module, $release ) = _get_meta( $module_name, $version );

    foreach my $dep ( @{ $release->{dependency} } ) {

        # Find latest version?
        # FIXME: What to do here?

    }

    # work out where to mirror to...
    my $file = $release->{download_url};
    $file =~ s{^.+/authors/}{};
    $file = file( $OUT_DIR, $file );
    $file->dir->mkpath();

    my $status = mirror( $release->{download_url}, $file->stringify );
    if ( is_success($status) || is_redirect($status) ) {
        $seen{$seen_key} = 1;
        $injector->{author} = $release->{author};
        $injector->inject( $file->stringify );
    } else {
        warn "Unable to mirror: " . $release->{download_url};
    }
}

sub _get_meta {
    my ( $module_name, $version ) = @_;

    my $module = $es->search(
        index  => 'v0',
        type   => 'file',
        query  => { match_all => {} },
        filter => {
            and => [
                { term => { 'file.authorized'     => 'true' } },
                { term => { 'file.module.name'    => $module_name } },
                { term => { 'file.module.version' => $version } }
            ]
        },
    );

    my $release_name = $module->{hits}{hits}[0]{_source}{release};

    my $release = $es->search(
        index  => 'v0',
        type   => 'release',
        query  => { match_all => {} },
        filter => { term => { 'release.name' => $release_name } },
    );
    return $module->{hits}{hits}[0]{_source},
        $release->{hits}{hits}[0]{_source};

}

