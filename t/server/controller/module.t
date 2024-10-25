use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestHelpers  qw( decode_json_ok test_cache_headers );
use MetaCPAN::Util         qw( hit_total );
use Test::More;

my %tests = (

    '/module' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
    '/module/DOY/Moose-0.01/lib/Moose.pm' => {
        code          => 200,
        cache_control => undef,
        surrogate_key =>
            'author=DOY content_type=application/json content_type=application',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
    },
    '/module/Moose' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
    '/module/Moose?fields=documentation,name' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },

    '/module/DOESNEXIST' => {
        code          => 404,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
    '/module/DOES/Not/Exist.pm' => {
        code          => 404,
        cache_control => undef,
        surrogate_key =>
            'author=DOES content_type=application/json content_type=application',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
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
        if ( $k eq '/module' ) {
            ok( hit_total($json), 'got total count' );
        }
        elsif ( $k =~ /fields/ ) {
            is_deeply(
                $json,
                { documentation => 'Moose', name => 'Moose.pm' },
                'controller proxies field query parameter to ES'
            );
        }
        elsif ( $v eq 200 ) {
            ok( $json->{name} eq 'Moose.pm', 'Moose.pm' );
        }
    }
};

done_testing;
