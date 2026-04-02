use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::ESConfig     qw( es_doc_path );
use MetaCPAN::Server::Test qw( app es GET query test_psgi );
use MetaCPAN::TestHelpers  qw( decode_json_ok );
use Test::Deep             qw( cmp_deeply ignore re );
use Test::More;

my $favorite = query()->favorite;
my $es       = es();

test_psgi app, sub {
    my $cb = shift;

    ok( my $user_res = $cb->( GET '/user?access_token=testing' ),
        'get user' );
    my $user_id = decode_json_ok($user_res)->{id};

    # Seeded favorites (dates set in TestServer::_create_test_favorites):
    #   Fav-Dist   2024-01-01
    #   Fav-DistC  2024-03-15
    #   Fav-DistB  2024-06-01

    my $fav_dist = {
        author       => 'LOCAL',
        distribution => 'Fav-Dist',
        date         => re(qr/^2024-01-01/),
    };
    my $fav_distb = {
        author       => 'LOCAL',
        distribution => 'Fav-DistB',
        date         => re(qr/^2024-06-01/),
    };
    my $fav_distc = {
        author       => 'LOCAL',
        distribution => 'Fav-DistC',
        date         => re(qr/^2024-03-15/),
    };

    subtest 'by_user returns seeded favorites' => sub {
        my $result = $favorite->by_user( $user_id, 1, 250 );
        cmp_deeply(
            $result,
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_dist, $fav_distb, $fav_distc ],
            },
            'returns all favorites sorted by distribution asc'
        );

        cmp_deeply(
            $favorite->by_user('nonexistent_user_id'),
            { favorites => [], took => 0, total => 0 },
            'unknown user returns empty result'
        );
    };

    subtest 'by_user sort param' => sub {
        cmp_deeply(
            $favorite->by_user( $user_id, 1, 250, 'distribution:desc' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_distc, $fav_distb, $fav_dist ],
            },
            'distribution:desc reverses default order'
        );
        cmp_deeply(
            $favorite->by_user( $user_id, 1, 250, 'date:asc' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_dist, $fav_distc, $fav_distb ],
            },
            'date:asc sorts oldest first'
        );
        cmp_deeply(
            $favorite->by_user( $user_id, 1, 250, 'date:desc' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_distb, $fav_distc, $fav_dist ],
            },
            'date:desc sorts newest first'
        );
        cmp_deeply(
            $favorite->by_user( $user_id, 1, 250, 'bogus' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_dist, $fav_distb, $fav_distc ],
            },
            'invalid sort falls back to default'
        );
        cmp_deeply(
            $favorite->by_user( $user_id, 1, 250, 'author:asc' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_dist, $fav_distb, $fav_distc ],
            },
            'disallowed field falls back to default'
        );
    };

    subtest 'recent sort param' => sub {
        cmp_deeply(
            $favorite->recent( 1, 100, 'date:asc' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_dist, $fav_distc, $fav_distb ],
            },
            'date:asc'
        );
        cmp_deeply(
            $favorite->recent( 1, 100, 'date:desc' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_distb, $fav_distc, $fav_dist ],
            },
            'date:desc'
        );
        cmp_deeply(
            $favorite->recent( 1, 100, 'distribution:asc' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_dist, $fav_distb, $fav_distc ],
            },
            'distribution:asc'
        );
        cmp_deeply(
            $favorite->recent( 1, 100, 'distribution:desc' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_distc, $fav_distb, $fav_dist ],
            },
            'distribution:desc'
        );
        cmp_deeply(
            $favorite->recent( 1, 100, 'bogus' ),
            {
                took      => ignore(),
                total     => 3,
                favorites => [ $fav_distb, $fav_distc, $fav_dist ],
            },
            'invalid sort falls back to date:desc'
        );
    };

    subtest 'partial backpan keeps distribution' => sub {
        $es->update_by_query(
            es_doc_path('release'),
            body => {
                query  => { term => { name => 'Fav-Dist-1.00' } },
                script => {
                    source => 'ctx._source.status = "backpan"',
                },
            },
        );
        $es->indices->refresh;

        my $result = $favorite->by_user( $user_id, 1, 250 );
        my %dists
            = map { $_->{distribution} => 1 } @{ $result->{favorites} };
        ok( $dists{'Fav-Dist'},
            'Fav-Dist still present after partial backpan' );
    };

    subtest 'full backpan excludes distribution' => sub {
        $es->update_by_query(
            es_doc_path('release'),
            body => {
                query  => { term => { distribution => 'Fav-Dist' } },
                script => {
                    source => 'ctx._source.status = "backpan"',
                },
            },
        );
        $es->indices->refresh;

        my $result = $favorite->by_user( $user_id, 1, 250 );
        my %dists
            = map { $_->{distribution} => 1 } @{ $result->{favorites} };
        ok( !$dists{'Fav-Dist'}, 'Fav-Dist excluded after full backpan' );

        # Fav-DistB and Fav-DistC are unaffected by the backpan update
        is( $result->{total}, 2, 'remaining favorites still returned' );
    };
};

done_testing;
