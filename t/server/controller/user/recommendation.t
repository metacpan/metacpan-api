
use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

test_psgi app, sub {
    my $cb = shift;

    ok( my $user = $cb->( GET '/user?access_token=testing' ), 'get user' );
    is( $user->code, 200, 'code 200' );
    ok( $user = decode_json( $user->content ), 'decode json' );

    ok( my $res = $cb->(
            POST '/user/recommendation?access_token=testing',
            Content => encode_json(
                {   module       => 'Moose',
                    instead_of   => 'Mouse'
                }
            )
        ),
        "POST recommendation"
    );
    is( $res->code, 201, 'status created' );
    ok( my $location = $res->header('location'), "location header set" );
    ok( $res = $cb->( GET $location ), "GET $location" );
    is( $res->code, 200, 'found' );
    my $json = decode_json( $res->content );
    is( $json->{user}, $user->{id}, 'user is ' . $user->{id} );
    ok( $res = $cb->( DELETE "/user/recommendation/Moose/instead_of/Mouse?access_token=testing" ),
        "DELETE /user/recommendation/Moose/instead_of/Mouse" );
    is( $res->code, 200, 'status ok' );
    ok( $res = $cb->( GET "$location?access_token=testing" ),
        "GET $location" );
    is( $res->code, 404, 'not found' );

    ok( $user = $cb->( GET '/user?access_token=bot' ), 'get bot' );
    is( $user->code, 200, 'code 200' );
    ok( $user = decode_json( $user->content ), 'decode json' );
    ok( !$user->{looks_human}, 'user looks like a bot' );
    ok( $res = $cb->(
            POST '/user/recommendation?access_token=bot',
            Content => encode_json(
                {   module => 'Moose',
                    instead_of      => 'Mouse',
                }
            )
        ),
        "POST recommendation"
    );
    ok( decode_json( $res->content ), 'decode response' );
    is( $res->code, 403, 'forbidden' );

};

done_testing;
