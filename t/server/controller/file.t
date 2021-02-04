use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw( decode_json_ok test_cache_headers );
use Test::More;

my %tests = (
    '/file' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
    '/file/8yTixXQGpkbPsMBXKvDoJV4Qkg8' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
    '/file/DOESNEXIST' => {
        code          => 404,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef,
    },
    '/file/DOES/Not/Exist.pm' => {
        code          => 404,
        cache_control => undef,
        surrogate_key =>
            'author=DOES content_type=application/json content_type=application',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
    },
    '/file/DOY/Moose-0.01/lib/Moose.pm' => {
        code          => 200,
        cache_control => undef,
        surrogate_key =>
            'author=DOY content_type=application/json content_type=application',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
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
        if ( $k eq '/file' ) {
            ok( $json->{hits}->{total}, 'got total count' );
        }
        elsif ( $v eq 200 ) {
            ok( $json->{name} eq 'Moose.pm', 'Moose.pm' );
        }
    }
};

done_testing;
