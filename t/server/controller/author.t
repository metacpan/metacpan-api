use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my %tests = (
    '/author'            => 200,
    '/author/MO'         => 200,
    '/author/DOESNEXIST' => 404,
    '/author/_mapping'   => 200
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v, "code $v" );
        is( $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );
        ok( $json->{pauseid} eq 'MO', 'pauseid is MO' )
            if ( $k eq '/author/MO' );
        ok( ref $json->{author} eq 'HASH', '_mapping' )
            if ( $k eq '/author/_mapping' );
    }

    ok(my $res = $cb->( GET '/author/MO?callback=jsonp'), "GET jsonp");
    is( $res->header('content-type'),
        'text/javascript; charset=UTF-8',
        'Content-type'
    );
    like( $res->content, qr/^jsonp\(.*\);$/ms, 'includes jsonp callback' );

    ok( $res = $cb->(
            POST '/author/_search',
            #'Content-type' => 'application/json',
            Content        => '{"query":{"match_all":{}},"size":0}'
        ),
        "POST _search"
    );
    ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );
    is( @{ $json->{hits}->{hits} }, 0, '0 results' );
};

done_testing;
