use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

my %tests = (
    '/source/DOESNEXIST'                           => 404,
    '/source/DOY/Moose-0.01/'                      => 200,
    '/source/DOY/Moose-0.01/Changes'               => 200,
    '/source/DOY/Moose-0.01/Changes?callback=foo'  => 200,
    '/source/DOY/Moose-0.01/MANIFEST'              => 200,
    '/source/DOY/Moose-0.01/MANIFEST?callback=foo' => 200,
    '/source/Moose'                                => 200,
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v, "code $v" );
        if ( $k eq '/source/Moose' ) {
            like( $res->content, qr/package Moose/, 'Moose source' );
            is(
                $res->header('content-type'),
                'text/plain; charset=UTF-8',
                'Content-type'
            );

            # Used for fastly on st.aticpan.org
            is( $res->header('X-Content-Type'),
                'text/x-script.perl-module', 'X-Content-Type' );

            is( $res->header('Surrogate-Control'),
                'max-age=86400', 'Surrogate-Control' );

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
                    my $jsdata
                        = JSON->new->allow_nonref->decode($function_args),
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
                is(
                    $res->header('content-type'),
                    'text/plain; charset=UTF-8',
                    'Content-type'
                );
            }
        }
        elsif ( $k eq '/source/DOY/Moose-0.01/Changes' ) {
            is(
                $res->header('content-type'),
                'text/plain; charset=UTF-8',
                'Content-type'
            );
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
        elsif ( $v eq 200 ) {
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
