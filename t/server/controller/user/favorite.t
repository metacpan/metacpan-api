use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw( decode_json_ok encode_json );
use Test::More;

test_psgi app, sub {
    my $cb = shift;

    ok( my $user = $cb->( GET '/user?access_token=testing' ), 'get user' );
    is( $user->code, 200, 'code 200' );
    $user = decode_json_ok($user);

    is_deeply(
        $user->{identity},
        [ {
            'key'  => 'MO',
            'name' => 'pause'
        } ],
        'got correct identity'
    );

    is_deeply(
        $user->{access_token},
        [ {
            'client' => 'testing',
            'token'  => 'testing'
        } ],
        'got correct access_token'
    );

    ok(
        my $res = $cb->(
            POST '/user/favorite?access_token=testing',
            Content_Type => 'application/json',
            Content      => encode_json( {
                distribution => 'Moose',
                release      => 'Moose-1.10',
                author       => 'DOY'
            } )
        ),
        'POST favorite'
    );
    is( $res->code, 201, 'status created' );
    ok( my $location = $res->header('location'), 'location header set' );
    ok( $res = $cb->( GET $location ), "GET $location" );
    is( $res->code, 200, 'found' );

    my $json = decode_json_ok($res);
    is( $json->{user}, $user->{id}, 'user is ' . $user->{id} );
    ok( $res = $cb->( DELETE '/user/favorite/Moose?access_token=testing' ),
        'DELETE /user/favorite/MO/Moose' );
    is( $res->code, 200, 'status ok' );
    ok( $res = $cb->( GET "$location?access_token=testing" ),
        "GET $location" );
    is( $res->code, 404, 'not found' );

    ok( $user = $cb->( GET '/user?access_token=bot' ), 'get bot' );
    is( $user->code, 200, 'code 200' );

    $user = decode_json_ok($user);
    ok( !$user->{looks_human}, 'user looks like a bot' );
    ok(
        $res = $cb->(
            POST '/user/favorite?access_token=bot',
            Content => encode_json( {
                distribution => 'Moose',
                release      => 'Moose-1.10',
                author       => 'DOY'
            } )
        ),
        'POST favorite'
    );
    decode_json_ok($res);
    is( $res->code, 403, 'forbidden' );
};

done_testing;
