
use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my %tests = (

    # TODO
    #'/pod'                             => 404,
    '/pod/DOESNEXIST'                  => 404,
    '/pod/Moose'                       => 200,
    '/pod/DOY/Moose-0.01/lib/Moose.pm' => 200,
    '/pod/Pod::Pm'                     => 200,
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
        if($k eq '/pod/Pod::Pm') {
            like( $res->content, qr/Pod::Pm - abstract/, 'NAME section' );
        } elsif ( $v eq 200 ) {
            like( $res->content, qr/Moose - abstract/, 'NAME section' );
            ok( $res = $cb->( GET "$k?content-type=text/plain" ),
                "GET plain" );
            is( $res->header('content-type'),
                'text/plain; charset=UTF-8',
                'Content-type'
            );
        }
        
    }
};

done_testing;
