use strict;
use warnings;
use Test::More;
use Path::Class qw(file);
use MetaCPAN::Server::Test;

my $fh = file('var/tmp/source/DOY/Moose-0.02/Moose-0.02/binary.bin')->openw;
print $fh "\x00" x 10;
$fh->close;

my %tests = (

    # TODO
    #'/pod'                            => 404,
    '/pod/DOESNEXIST'                  => 404,
    '/pod/Moose'                       => 200,
    '/pod/DOY/Moose-0.01/lib/Moose.pm' => 200,
    '/pod/DOY/Moose-0.02/binary.bin'   => 400,
    '/pod/Pod::Pm'                     => 200,
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v, "code $v" );
        is( $res->header('content-type'),
            $v == 200
            ? 'text/html; charset=UTF-8'
            : 'application/json; charset=utf-8',
            'Content-type'
        );
        if($k eq '/pod/Pod::Pm') {
            like( $res->content, qr/Pod::Pm - abstract/, 'NAME section' );
        } elsif ( $v == 200 ) {
            like( $res->content, qr/Moose - abstract/, 'NAME section' );
            ok( $res = $cb->( GET "$k?content-type=text/plain" ),
                "GET plain" );
            is( $res->header('content-type'),
                'text/plain; charset=UTF-8',
                'Content-type'
            );
        } elsif ( $v == 404 ) {
            like( $res->content, qr/Not found: (\w+)/, "404 correct error");
        }
        
        my $ct = $k =~ /Moose[.]pm$/ ? '&content-type=text/x-pod' : '';
        ok( $res = $cb->( GET "$k?callback=foo$ct"), "GET $k with callback" );
        is( $res->code, $v, "code $v" );
        is( $res->header('content-type'),
            'text/javascript; charset=UTF-8',
            'Content-type'
        );
        ok( my( $function_args ) = $res->content =~ /^foo\((.*)\)/s, 'callback included');
        ok( my $jsdata = JSON->new->allow_nonref->decode( $function_args ), 'decode json' );
        if ( $v eq 200 ) {
            if($ct) {
                like( $jsdata, qr{=head1 NAME}, 'POD body was JSON encoded' );
            }
            else {
                like( $jsdata, qr{<h1 id="NAME">NAME</h1>}, 'HTML body was JSON encoded' );
            }
        }
        else {
            ok( $jsdata->{message}, 'error response body was JSON encoded' );
        }
    }
};

done_testing;
