use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestHelpers  qw( decode_json_ok );
use Test::More;

test_psgi app, sub {
    my $cb = shift;

    subtest 'unknown user returns empty structured response' => sub {
        ok( my $res = $cb->( GET '/favorite/by_user/DOESNOTEXIST' ),
            'GET /favorite/by_user/DOESNOTEXIST' );
        is( $res->code, 200, 'code 200' );
        my $json = decode_json_ok($res);
        is_deeply(
            $json,
            { favorites => [], took => 0, total => 0 },
            'empty structured result for unknown user'
        );
    };

    subtest 'unknown user with pagination params' => sub {
        ok(
            my $res = $cb->(
                GET '/favorite/by_user/DOESNOTEXIST?page=1&page_size=10'
            ),
            'GET /favorite/by_user/DOESNOTEXIST with pagination params'
        );
        is( $res->code, 200, 'code 200' );
        my $json = decode_json_ok($res);
        is_deeply(
            $json,
            { favorites => [], took => 0, total => 0 },
            'empty structured result with pagination'
        );
    };

    subtest 'page beyond MAX_FAVORITE_RESULT_WINDOW returns empty' => sub {
        ok(
            my $res = $cb->(
                GET '/favorite/by_user/DOESNOTEXIST?page=21&page_size=250'
            ),
            'GET with page*size > MAX_FAVORITE_RESULT_WINDOW'
        );
        is( $res->code, 200, 'code 200' );
        my $json = decode_json_ok($res);
        is_deeply(
            $json,
            { favorites => [], took => 0, total => 0 },
            'empty structured result for out-of-window request'
        );
    };

    subtest 'page at MAX_FAVORITE_RESULT_WINDOW boundary is allowed' => sub {
        ok(
            my $res = $cb->(
                GET '/favorite/by_user/DOESNOTEXIST?page=20&page_size=250'
            ),
            'GET with page*size == MAX_FAVORITE_RESULT_WINDOW'
        );
        is( $res->code, 200, 'code 200' );
        my $json = decode_json_ok($res);
        is_deeply(
            $json,
            { favorites => [], took => 0, total => 0 },
            'boundary page returns valid structured response'
        );
    };
};

done_testing;
