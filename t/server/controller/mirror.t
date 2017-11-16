use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

my %tests = (
    '/mirror' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
    '/mirror/DOESNEXIST' => {
        code          => 404,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
    '/mirror/search?q=*' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
);

test_psgi app, sub {
    my $cb = shift;
    for my $k ( sort keys %tests ) {
        my $v = $tests{$k};
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v->{code}, "code " . $v->{code} );
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        test_cache_headers( $res, $v );

        decode_json_ok($res);
    }
};

done_testing;
