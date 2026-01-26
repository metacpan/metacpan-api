use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS      ();
use HTTP::Request::Common qw( GET );
use MetaCPAN::Server      ();
use MetaCPAN::TestHelpers qw( test_cache_headers );
use Plack::Test           ();
use Test::More;
use Try::Tiny qw( try );

my @tests = (
    {
        url     => '/pod/DOESNOTEXIST',
        headers => {
            code          => 404,
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
        },
    },
    {
        url     => '/pod/DOY/Moose-0.02/binary.bin',
        headers => {
            code          => 400,
            cache_control => undef,
            surrogate_key =>
                'author=DOY content_type=application/json content_type=application',
            surrogate_control =>
                'max-age=31556952, stale-while-revalidate=86400, stale-if-error=2592000',
        },
    },
    {
        url     => '/pod/DOY/Moose-0.01/lib/Moose.pm',
        headers => {
            code          => 200,
            cache_control => undef,
            surrogate_key =>
                'author=DOY content_type=text/html content_type=text',
            surrogate_control =>
                'max-age=31556952, stale-while-revalidate=86400, stale-if-error=2592000',
        },
    },
    {
        url     => '/pod/Moose',
        headers => {
            code          => 200,
            cache_control => undef,
            surrogate_key =>
                'author=DOY content_type=text/html content_type=text',
            surrogate_control =>
                'max-age=31556952, stale-while-revalidate=86400, stale-if-error=2592000',
        },
    },
    {
        url     => '/pod/Pod::Pm',
        headers => {
            code          => 200,
            cache_control => undef,
            surrogate_key =>
                'author=MO content_type=text/html content_type=text',
            surrogate_control =>
                'max-age=31556952, stale-while-revalidate=86400, stale-if-error=2592000',
        },
    },
);

my $app    = MetaCPAN::Server->new->to_app();
my $server = Plack::Test->create($app);

for my $test (@tests) {
    my $url = $test->{url};
    subtest $url => sub {
        my $res = $server->request( GET $url );
        ok( $res, "GET $url" );
        is(
            $res->code,
            $test->{headers}->{code},
            "code " . $test->{headers}->{code}
        );
        is(
            $res->header('content-type'),
            $test->{headers}->{code} == 200
            ? 'text/html; charset=UTF-8'
            : 'application/json; charset=utf-8',
            'Content-type'
        );

        test_cache_headers( $res, $test->{headers} );

        if ( $url eq '/pod/Pod::Pm' ) {
            like( $res->content, qr/Pod::Pm - abstract/, 'NAME section' );
        }
        elsif ( $test->{headers}->{code} == 200 ) {
            like( $res->content, qr/Moose - abstract/, 'NAME section' );
            $res = $server->request( GET "$url?content-type=text/plain" );
            is(
                $res->header('content-type'),
                'text/plain; charset=UTF-8',
                'Content-type'
            );
        }
        elsif ( $test->{headers}->{code} == 404 ) {
            like( $res->content, qr/Not found/, '404 correct error' );
        }

        my $ct = $url =~ /Moose[.]pm$/ ? '&content-type=text/x-pod' : q[];
        $res = $server->request( GET "$url?callback=foo$ct" );
        is(
            $res->code,
            $test->{headers}->{code},
            "code " . $test->{headers}->{code}
        );
        is(
            $res->header('content-type'),
            'text/javascript; charset=UTF-8',
            'Content-type'
        );

        ok( my ($function_args) = $res->content =~ /^\/\*\*\/foo\((.*)\)/s,
            'callback included' );
        my $js_data;
        try {
            $js_data
                = Cpanel::JSON::XS->new->allow_blessed->allow_nonref->binary
                ->decode($function_args);
        };
        ok( $js_data, 'decode json' );

        if ( $test->{headers}->{code} eq 200 ) {
            if ($ct) {
                like( $js_data, qr{=head1 NAME},
                    'POD body was JSON encoded' );
            }
            else {
                like(
                    $js_data,
                    qr{<h1 id="NAME">NAME</h1>},
                    'HTML body was JSON encoded'
                );
            }
        }
        else {
            ok( $js_data->{message}, 'error response body was JSON encoded' );
        }
    }
}

{
    my $path = '/pod/BadPod';
    my $res  = $server->request( GET $path );
    ok( $res, "GET $path" );
    is( $res->code, 200, 'code 200' );
    unlike(
        $res->content,
        qr/<div[^>]*class="pod-errors"/,
        'no POD errors section'
    );

}

{
    my $path = '/pod/BadPod?show_errors=1';
    my $res  = $server->request( GET $path );
    ok( $res, "GET $path" );
    is( $res->code, 200, 'code 200' );
    like(
        $res->content,
        qr/<div[^>]*class="pod-errors"/,
        'got POD errors section'
    );

    my @err = $res->content =~ m{<dd.*?>(.*?)</dd>}sg;
    is( scalar(@err), 2, 'two parse errors listed ' );
    like( $err[0], qr/=head\b/, 'first error mentions =head' );
    like( $err[1], qr/C&lt;/,   'first error mentions C< ... >' );
}

done_testing;
