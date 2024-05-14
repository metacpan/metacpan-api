use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw( decode_json_ok test_cache_headers );
use Cpanel::JSON::XS      qw(encode_json);
use Test::More;

test_psgi app, sub {
    my $cb = shift;

    my $res;

    ok( $res = $cb->( GET '/rating/random-id' ), 'GET /rating/random-id' );

    is $res->code, 404, 'not found';

    ok( $res = $cb->( GET '/rating/_mapping' ), 'GET /rating/_mapping' );

    is $res->code, 404, 'not found';

    ok( $res = $cb->( GET '/rating/by_distributions?distribution=Moose' ),
        'GET /rating/by_distributions' );

    is $res->code, 200, 'found';

    my $ratings = decode_json_ok($res);

    is_deeply $ratings->{distributions}, {}, 'empty distributions';

    ok(
        $res = $cb->(
            POST '/rating/_search',
            Content => '{"query":{"term":{"distribution":"Moose"}}}'
        ),
        'POST /rating/_search'
    );

    is $res->code, 200, 'found';

    $ratings = decode_json_ok($res);

    is_deeply $ratings->{hits}{hits}, [], 'no hits';

    ok(
        $res = $cb->(
            POST '/rating',
            Content => '{"query":{"term":{"distribution":"Moose"}}}',
        ),
        'POST /rating'
    );

    is $res->code, 200, 'found';

    $ratings = decode_json_ok($res);

    is_deeply $ratings->{hits}{hits}, [], 'no hits';

    ok(
        $res = $cb->(
            POST '/rating/_search?scroll=5m',
            Content => '{"query":{"term":{"distribution":"Moose"}}}',
        ),
        'POST /rating'
    );

    is $res->code, 200, 'found';

    $ratings = decode_json_ok($res);

    is_deeply $ratings->{hits}{hits}, [], 'no hits';

    is_deeply $ratings->{_scroll_id}, 'FAKE_SCROLL_ID',
        'gives fake scroll id';

    ok(
        $res
            = $cb->( POST "/_search/scroll/$ratings->{_scroll_id}?scroll=5m",
            ),
        'POST /_search/scroll/$id',
    );

    is $res->code, 200, 'found'
        or diag $res->as_string;

    $ratings = decode_json_ok($res);

    is_deeply $ratings->{hits}{hits}, [], 'working with no hits';
    is $ratings->{_shards}{total}, 0, 'results are fake';

    ok(
        $res = $cb->(
            POST '/rating/_search',
            'User-Agent' => 'MetaCPAN::Client-testing/2.031001',
            Content      => '{"query":{"term":{"distribution":"Moose"}}}',
        ),
        'POST /rating with MetaCPAN::Client test UA'
    );

    is $res->code, 200, 'found';

    $ratings = decode_json_ok($res);

    is_deeply $ratings->{hits}{hits},
        [
        {
            _source => {
                distribution => 'Moose',
            },
        },
        ],
        'no hits';

};

done_testing;

