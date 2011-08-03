use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

test_psgi app, sub {
    my $cb = shift;
    ok( my $res = $cb->( GET '/diff/release/Moose'), "GET /diff/Moose" );
    is( $res->code, 200, "code 200" );
    ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );

    ok( $res = $cb->( GET '/diff/release/DOY/Moose-0.01/DOY/Moose-0.02/'), "GET /diff/Moose/DOY..." );
    is( $res->code, 200, "code 200" );
    ok( my $json2 = eval { decode_json( $res->content ) }, 'valid json' );
    is_deeply($json, $json2, 'json matches with previous run');
    
    ok( $res = $cb->( GET '/diff/file/8yTixXQGpkbPsMBXKvDoJV4Qkg8/dPgxn7qq0wm1l_UO1aIMyQWFJPw'), "GET diff Moose.pm" );
    is( $res->code, 200, "code 200" );
    ok( $json = eval { decode_json( $res->content ) }, 'valid json' );
    
};

done_testing;
