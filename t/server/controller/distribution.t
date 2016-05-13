use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

my @tests = (
    [ '/distribution'            => 200 ],
    [ '/distribution/DOESNEXIST' => 404 ],
    [ '/distribution/Moose'      => 200 ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ( $k, $v ) = @{$test};
        ok( my $res = $cb->( GET $k), "GET $k" );

        # TRAVIS 5.18
        is( $res->code, $v, "code $v" );
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
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
