use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my @tests = (
    [ '/distribution'            => 200 ],
    [ '/distribution/Moose'      => 200 ],
    [ '/distribution/DOESNEXIST' => 404 ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ($k, $v) = @{ $test };
        ok( my $res = $cb->( GET $k), "GET $k" );
        # TRAVIS 5.18
        is( $res->code, $v, "code $v" );
        is( $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );
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
