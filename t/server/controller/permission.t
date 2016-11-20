use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

my %tests = (
    '/author' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
    '/author/DOESNEXIST' => {
        code          => 404,
        cache_control => undef,
        surrogate_key =>
            'author=DOESNEXIST content_type=application/json content_type=application',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
    },
    '/author/MO' => {
        code          => 200,
        cache_control => undef,
        surrogate_key =>
            'author=MO content_type=application/json content_type=application',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
    },
    '/author/_mapping' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v->{code}, "code " . $v->{code} );
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );

        test_cache_headers( $res, $v );

        my $json = decode_json_ok($res);
        ok( $json->{pauseid} eq 'MO', 'pauseid is MO' )
            if ( $k eq '/author/MO' );

        if ( $k eq '/author/_mapping' ) {
            my ($index) = keys %{$json};
            ok( ref $json->{$index}{mappings}{author} eq 'HASH', '_mapping' );
        }
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
    is( @{ $json->{release}->{hits}->{hits} }, 4, 'joined 4 releases' );

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
                                                'status' => 'latest'
                                            }
                                        },
                                        {
                                            term => { 'pauseid' => 'DOY' }
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

    my $release_count = delete $doy->{release_count};
    is_deeply(
        [ sort keys %{$release_count} ],
        [qw< backpan-only cpan latest >],
        'release_count has the correct keys'
    );

    my $links = delete $doy->{links};
    is_deeply(
        [ sort keys %{$links} ],
        [
            qw< backpan_directory cpan_directory cpantesters_matrix cpantesters_reports cpants metacpan_explorer >
        ],
        'links has the correct keys'
    );

    my $source = $json->{hits}->{hits}->[0]->{_source};
    is_deeply( $doy, $source, 'same result as direct get' );

    {
        ok( my $res = $cb->( GET '/author/_search?q=*&size=99999' ),
            'GET size=99999' );
        is( $res->code, 416, 'bad request' );
    }

};

done_testing;
