use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

my %tests = (
    '/author'            => 200,
    '/author/DOESNEXIST' => 404,
    '/author/MO'         => 200,
    '/author/_mapping'   => 200,
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
        ok( $json->{pauseid} eq 'MO', 'pauseid is MO' )
            if ( $k eq '/author/MO' );
        ok( ref $json->{cpan_v1}{mappings}{author} eq 'HASH', '_mapping' )
            if ( $k eq '/author/_mapping' );
    }

    ok( my $res = $cb->( GET '/author/MO?callback=jsonp' ), 'GET jsonp' );
    is(
        $res->header('content-type'),
        'text/javascript; charset=UTF-8',
        'Content-type'
    );
    like( $res->content, qr/^\/\*\*\/jsonp\(.*\);$/ms,
        'includes jsonp callback' );

    ok(
        $res = $cb->(
            POST '/author/_search',

            #'Content-type' => 'application/json',
            Content => '{"query":{"match_all":{}},"size":0}'
        ),
        'POST _search'
    );

    my $json = decode_json_ok($res);
    is( @{ $json->{hits}->{hits} }, 0, '0 results' );

    ok( $res = $cb->( GET '/author/DOY?join=release' ),
        'GET /author/DOY?join=release' );

    $json = decode_json_ok($res);
    is( @{ $json->{release}->{hits}->{hits} }, 2, 'joined 2 releases' );

    ok(
        $res = $cb->(
            POST '/author/DOY?join=release',
            Content => encode_json(
                {
                    query => {
                        constant_score =>
                            { filter => { term => { status => 'latest' } } }
                    }
                }
            )
        ),
        'POST /author/DOY?join=release with query body',
    );

    $json = decode_json_ok($res);
    is( @{ $json->{release}->{hits}->{hits} }, 1, 'joined 1 release' );
    is( $json->{release}->{hits}->{hits}->[0]->{_source}->{status},
        'latest', '1 release has status latest' );

    ok(
        $res = $cb->(
            POST '/author/_search?join=release',
            Content => encode_json(
                {
                    query => {
                        constant_score => {
                            filter => {
                                bool => {
                                    should => [
                                        {
                                            term => {
                                                'release.status' => 'latest'
                                            }
                                        },
                                        {
                                            term =>
                                                { 'author.pauseid' => 'DOY' }
                                        }
                                    ]
                                }
                            }
                        }
                    }
                }
            )
        ),
        'POST /author/_search?join=release with query body'
    );

    my $doy = $json;
    $json = decode_json_ok($res);

    is( @{ $json->{hits}->{hits} }, 1, '1 hit' );
    is_deeply( $json->{hits}->{hits}->[0]->{_source},
        $doy, 'same result as direct get' );

    {
        ok( my $res = $cb->( GET '/author/_search?q=*&size=99999' ),
            'GET size=99999' );
        is( $res->code, 416, 'bad request' );
    }

};

done_testing;
