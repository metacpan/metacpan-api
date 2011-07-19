
use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my %tests = (
    '/source/DOESNEXIST'      => 404,
    '/source/DOY/Moose-0.01/' => 200,
    '/source/Moose'           => 200,
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v, "code $v" );
        if ( $k eq '/source/Moose' ) {
            like( $res->content, qr/package Moose/, 'Moose source' );
            is( $res->header('content-type'),
                'text/plain; charset=UTF-8',
                'Content-type'
            );
        }
        elsif ( $v eq 200 ) {
            like( $res->content, qr/Index of/, 'Index of' );
            is( $res->header('content-type'),
                'text/html; charset=UTF-8',
                'Content-type'
            );

        }
        else {
            is( $res->header('content-type'),
                'application/json; charset=utf-8',
                'Content-type'
            );
        }
    }
};

done_testing;
