use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw( decode_json_ok test_cache_headers );
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
            POST '/rating/_search',
            Content => '{"query":{"term":{"distribution":"Moose"}}}'
        ),
        'POST /rating'
    );

    is $res->code, 200, 'found';

    $ratings = decode_json_ok($res);

    is_deeply $ratings->{hits}{hits}, [], 'no hits';
};

done_testing;

