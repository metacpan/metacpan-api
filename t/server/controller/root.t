use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

test_psgi app, sub {
    my $cb = shift;
    ok( my $res = $cb->( GET '/' ), "GET /" );
    is( $res->code, 302, 'got redirect' );
    is(
        $res->header('Location'),
        'https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md',
        'correct redirect target'
    );
};

done_testing;
