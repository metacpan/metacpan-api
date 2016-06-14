use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

my %tests = (
    '/module'                                 => 200,
    '/module/DOESNEXIST'                      => 404,
    '/module/DOES/Not/Exist.pm'               => 404,
    '/module/DOY/Moose-0.01/lib/Moose.pm'     => 200,
    '/module/Moose'                           => 200,
    '/module/Moose?fields=documentation,name' => 200,
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v, "code $v" );
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );

        my $json = decode_json_ok($res);
        if ( $k eq '/module' ) {
            ok( $json->{hits}->{total}, 'got total count' );
        }
        elsif ( $k =~ /fields/ ) {
            is_deeply(
                $json,
                { documentation => ['Moose'], name => ['Moose.pm'] },
                'controller proxies field query parameter to ES'
            );
        }
        elsif ( $v eq 200 ) {
            ok( $json->{name} eq 'Moose.pm', 'Moose.pm' );
        }
    }
};

done_testing;
