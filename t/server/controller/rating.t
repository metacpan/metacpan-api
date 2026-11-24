use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET POST test_psgi );
use Test::More;

my $query = '{"query":{"term":{"distribution":"Moose"}}}';

test_psgi app, sub {
    my $cb = shift;

    for my $req (
        POST( '/rating',         Content => $query ),
        POST( '/rating/_search', Content => $query ),
        GET('/rating/by_distributions?distribution=Moose'),
        GET('/rating/random-id'),
    ) {
        my $res = $cb->($req);
        is $res->code, 404, $req->method . ' ' . $req->uri . ' is gone';
    }
};

done_testing;
