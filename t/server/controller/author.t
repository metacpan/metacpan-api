use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET POST test_psgi es );
use MetaCPAN::TestHelpers  qw( decode_json_ok test_cache_headers );
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
        ok( my $res = $cb->( GET $k ), "GET $k" );
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
            my $check_mappings = $json->{$index}{mappings};
            if ( es->api_version le '5_0' ) {
                $check_mappings = $check_mappings->{author};
            }

            ok( $check_mappings->{properties}{name}, '_mapping' );
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

    ok( $res = $cb->( GET '/author/DOY' ), 'GET /author/DOY' );

    my $doy = decode_json_ok($res);

    is( $doy->{pauseid}, 'DOY', 'found author' );

    my $links = $doy->{links};
    is_deeply(
        [ sort keys %{$links} ],
        [
            qw< backpan_directory cpan_directory cpantesters_matrix cpantesters_reports cpants metacpan_explorer repology>
        ],
        'links has the correct keys'
    );

    {
        ok( my $res = $cb->( GET '/author/_search?q=*&size=99999' ),
            'GET size=99999' );
        is( $res->code, 416, 'bad request' );
    }

};

done_testing;
