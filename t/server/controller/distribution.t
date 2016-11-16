use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

my @tests = (
    [
        '/distribution' => {
            code          => 200,
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
        }
    ],
    [
        '/distribution/DOESNEXIST' => {
            code          => 404,
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
        }
    ],
    [
        '/distribution/Moose' => {
            code          => 200,
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
        }
    ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ( $k, $v ) = @{$test};
        ok( my $res = $cb->( GET $k), "GET $k" );

        # TRAVIS 5.18
        is( $res->code, $v->{code}, "code " . $v->{code} );
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        test_cache_headers( $res, $v );

        my $json = decode_json_ok($res);
        if ( $k eq '/distribution' ) {
            ok( $json->{hits}->{total}, 'got total count' );
        }
        elsif ( $v eq 200 ) {

            # TRAVIS 5.18
            ok( $json->{name} eq 'Moose', 'Moose' );
        }
    }
};

done_testing;
