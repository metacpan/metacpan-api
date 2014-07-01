use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

test_psgi app, sub {
    my $cb = shift;

    ok( my $user = $cb->( GET '/user?access_token=testing' ), 'get user' );
    is( $user->code, 200, 'code 200' );
    ok( $user = decode_json( $user->content ), 'decode json' );

    ok(
        my $res = $cb->(
            POST '/user/stargazer?access_token=testing',
            Content => encode_json(
                {
                    module	 => 'Moose::Cookbook',
                    release      => 'Moose-2.1209',
                    author       => 'DOY'
                }
            )
        ),
        "POST stargazer"
    );
    is( $res->code, 201, 'status created' );
    ok( my $location = $res->header('location'), "location header set" );
    ok( $res = $cb->( GET $location ), "GET $location" );
    is( $res->code, 200, 'found' );
    my $json = decode_json( $res->content );
    is( $json->{user}, $user->{id}, 'user is ' . $user->{id} );
    ok( $res = $cb->( DELETE "/user/stargazer/Moose::Cookbook?access_token=testing" ),
        "DELETE /user/stargazer/MO/Moose::Cookbook" );
    is( $res->code, 200, 'status ok' );
    ok( $res = $cb->( GET "$location?access_token=testing" ),
        "GET $location" );
    is( $res->code, 404, 'not found' );

    ok( $user = $cb->( GET '/user?access_token=bot' ), 'get bot' );
    is( $user->code, 200, 'code 200' );
    ok( $user = decode_json( $user->content ), 'decode json' );
    ok( !$user->{looks_human}, 'user looks like a bot' );
    ok(
        $res = $cb->(
            POST '/user/stargazer?access_token=bot',
            Content => encode_json(
                {
                    module => 'Moose::Cookbook',
                    release      => 'Moose-2.1209',
                    author       => 'DOY'
                }
            )
        ),
        "POST stargazer"
    );
    ok( decode_json( $res->content ), 'decode response' );
    is( $res->code, 403, 'forbidden' );

};

done_testing;
