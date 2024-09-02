use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS       ();
use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestHelpers  qw( test_cache_headers );
use Test::More;

my %tests = (
    '/source/DOESNEXIST' => {
        code          => 404,
        cache_control => 'private',
        surrogate_key =>
            'content_type=application/json content_type=application',
        surrogate_control => undef
    },
    '/source/DOY/Moose-0.01/' => {
        code          => 200,
        cache_control => undef,
        surrogate_key =>
            'author=DOY content_type=text/html content_type=text',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000'
    },
    '/source/DOY/Moose-0.01/Changes' => {
        code          => 200,
        cache_control => undef,
        surrogate_key =>
            'author=DOY content_type=text/plain content_type=text',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
    },
    '/source/DOY/Moose-0.01/Changes?callback=foo' => {
        code          => 200,
        cache_control => undef,
        surrogate_key =>
            'author=DOY content_type=text/javascript content_type=text',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
    },
    '/source/DOY/Moose-0.01/MANIFEST' => {
        code          => 200,
        cache_control => undef,
        surrogate_key =>
            'author=DOY content_type=text/plain content_type=text',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
    },
    '/source/DOY/Moose-0.01/MANIFEST?callback=foo' => {
        code          => 200,
        cache_control => undef,
        surrogate_key =>
            'author=DOY content_type=text/javascript content_type=text',
        surrogate_control => 'max-age=31556952, stale-if-error=2592000',
    },
    '/source/Moose' => {
        code          => 200,
        cache_control => 'private',
        surrogate_key =>
            'author=DOY content_type=text/plain content_type=text',
        surrogate_control => undef
    },
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k ), "GET $k" );
        is( $res->code, $v->{code}, "code " . $v->{code} );

        test_cache_headers( $res, $v );

        if ( $k eq '/source/Moose' ) {
            like( $res->content, qr/package Moose/, 'Moose source' );
            is( $res->header('content-type'), 'text/plain', 'Content-type' );

            # Used for fastly on st.aticpan.org
            is( $res->header('X-Content-Type'),
                'text/x-script.perl-module', 'X-Content-Type' );

        }
        elsif ( $k =~ /MANIFEST/ ) {

            # No EOL.
            my $manifest = join(
                "\n", qw(
                    MANIFEST
                    lib/Moose.pm
                    Makefile.PL
                    t/00-nop.t
                    META.json
                    META.yml
                )
            );
            if ( $k =~ /callback=foo/ ) {
                ok(
                    my ($function_args)
                        = $res->content =~ /^\/\*\*\/foo\((.*)\)/s,
                    'JSONP wrapper'
                );
                ok(
                    my $jsdata = Cpanel::JSON::XS->new->allow_nonref->decode(
                        $function_args),
                    'decode json'
                );
                is( $jsdata, $manifest, 'JSONP-wrapped manifest' );
                is(
                    $res->header('content-type'),
                    'text/javascript; charset=UTF-8',
                    'Content-type'
                );
            }
            else {
                is( $res->content, $manifest, 'Plain text manifest' );
                is( $res->header('content-type'),
                    'text/plain', 'Content-type' );
            }
        }
        elsif ( $k eq '/source/DOY/Moose-0.01/Changes' ) {
            is( $res->header('content-type'), 'text/plain', 'Content-type' );
            like(
                $res->decoded_content,
                qr/codename 'M\x{fc}nchen'/,
                'Change-log content'
            );
        }
        elsif ( $k eq '/source/DOY/Moose-0.01/Changes?callback=foo' ) {
            is(
                $res->header('content-type'),
                'text/javascript; charset=UTF-8',
                'Content-type'
            );
            ok(
                my ($function_args)
                    = $res->content =~ /^\/\*\*\/foo\((.*)\)/s,
                'JSONP wrapper'
            );
            ok(
                my $jsdata = JSON->new->allow_nonref->decode($function_args),
                'decode json'
            );
            like(
                $jsdata,
                qr/codename 'M\x{fc}nchen'/,
                'JSONP-wrapped change-log'
            );
        }
        elsif ( $v->{code} eq 200 ) {
            like( $res->content, qr/Index of/, 'Index of' );
            is(
                $res->header('content-type'),
                'text/html; charset=UTF-8',
                'Content-type'
            );

        }
        else {
            is(
                $res->header('content-type'),
                'application/json; charset=utf-8',
                'Content-type'
            );
        }
    }
};

done_testing;
