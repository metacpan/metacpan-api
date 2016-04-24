use strict;
use warnings;

use Cpanel::JSON::XS ();
use HTTP::Request::Common qw( GET );
use MetaCPAN::Server ();
use MetaCPAN::Server::App;
use Path::Class qw(dir);
use Plack::Test;
use Test::More;
use Try::Tiny qw( catch try );

my $dir = dir( MetaCPAN::Server->model('Source')->base_dir,
    'DOY/Moose-0.02/Moose-0.02' );
$dir->mkpath;

my $file = $dir->file('binary.bin');
$file->openw->print( "\x00" x 10 );

my %tests = (

    # TODO
    #'/pod'                            => 404,
    '/pod/DOESNEXIST'                  => 404,
    '/pod/DOY/Moose-0.01/lib/Moose.pm' => 200,
    '/pod/DOY/Moose-0.02/binary.bin'   => 400,
    '/pod/Moose'                       => 200,
    '/pod/Pod::Pm'                     => 200,
);

my $app  = MetaCPAN::Server->new->to_app();
my $test = Plack::Test->create($app);

while ( my ( $k, $v ) = each %tests ) {
    my $res = $test->request( GET $k);
    ok( $res, "GET $k" );
    is( $res->code, $v, "code $v" );
    is(
        $res->header('content-type'),
        $v == 200
        ? 'text/html; charset=UTF-8'
        : 'application/json; charset=utf-8',
        'Content-type'
    );

    if ( $k eq '/pod/Pod::Pm' ) {
        like( $res->content, qr/Pod::Pm - abstract/, 'NAME section' );
    }
    elsif ( $v == 200 ) {
        like( $res->content, qr/Moose - abstract/, 'NAME section' );
        $res = $test->request( GET "$k?content-type=text/plain" );
        is(
            $res->header('content-type'),
            'text/plain; charset=UTF-8',
            'Content-type'
        );
    }
    elsif ( $v == 404 ) {
        like( $res->content, qr/Not found/, '404 correct error' );
    }

    my $ct = $k =~ /Moose[.]pm$/ ? '&content-type=text/x-pod' : q[];
    $res = $test->request( GET "$k?callback=foo$ct" );
    is( $res->code, $v, "code $v" );
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

    if ( $v eq 200 ) {

        if ($ct) {
            like( $js_data, qr{=head1 NAME}, 'POD body was JSON encoded' );
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

{
    my $path = '/pod/BadPod';
    my $res  = $test->request( GET $path );
    ok( $res, "GET $path" );
    is( $res->code, 200, 'code 200' );
    unlike( $res->content, qr/<div[^>]*id="pod-errors"/,
        'no POD errors section' );

}

{
    my $path = '/pod/BadPod?show_errors=1';
    my $res  = $test->request( GET $path);
    ok( $res, "GET $path" );
    is( $res->code, 200, 'code 200' );
    like( $res->content, qr/<div[^>]*id="pod-errors"/,
        'got POD errors section' );

    my @err = $res->content =~ m{<dd.*?>(.*?)</dd>}sg;
    is( scalar(@err), 2, 'two parse errors listed ' );
    like( $err[0], qr/=head\b/, 'first error mentions =head' );
    like( $err[1], qr/C&lt;/,   'first error mentions C< ... >' );
}

done_testing;
