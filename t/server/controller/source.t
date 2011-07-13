
use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my %tests = (
    '/source/DOESNEXIST'      => 404,
    '/source/DOY/Moose-0.01/' => 200,
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v, "code $v" );
        is( $res->header('content-type'),
            $v == 200
            ? 'text/html; charset=UTF-8'
            : 'application/json; charset=utf-8',
            'Content-type'
        );
        if ( $v eq 200 ) {
            like( $res->content, qr/Index of/, 'Index of' );
        }
    }
};

done_testing;
