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

    subtest 'by_user returns seeded favorites' => sub {
        my $result = $favorite->by_user( $user_id, 1, 250 );
        cmp_deeply(
            $result,
            {
                took      => ignore(),
                total     => 1,
                favorites => [
                    {
                        author       => 'LOCAL',
                        distribution => 'Fav-Dist',
                        date         => re(qr/^\d{4}-\d{2}-\d{2}/),
                    },
                ],
            },
            'returns expected favorites'
        );

        cmp_deeply(
            $favorite->by_user('nonexistent_user_id'),
            { favorites => [], took => 0, total => 0 },
            'unknown user returns empty result'
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
        is_deeply( \%dists, { 'Fav-Dist' => 1 } );
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
        cmp_deeply(
            $result,
            { favorites => [], took => ignore(), total => 0 },
            'no favorites when all are backpan'
        );
    };
};

done_testing;
