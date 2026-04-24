use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS       qw( encode_json );
use MetaCPAN::ESConfig     qw( es_doc_path );
use MetaCPAN::Server::Test qw( app DELETE es GET POST test_psgi );
use MetaCPAN::TestHelpers  qw( decode_json_ok );
use MetaCPAN::Util         qw( hit_total );
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
                distribution => 'Scripts',
                release      => 'Scripts-0.01',
                author       => 'MO'
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
    ok(
        $res = $cb->( DELETE '/user/favorite/Scripts?access_token=testing' ),
        'DELETE /user/favorite/Scripts'
    );
    is( $res->code, 200, 'status ok' );
    ok( $res = $cb->( GET "$location?access_token=testing" ),
        "GET $location" );
    is( $res->code, 404, 'not found' );

    ok( $user = $cb->( GET '/user?access_token=bot' ), 'get bot' );
    is( $user->code, 200, 'code 200' );
};

subtest 'API enforces uniqueness on (user, distribution)' => sub {
    test_psgi app, sub {
        my $cb = shift;

        ok( my $user_res = $cb->( GET '/user?access_token=testing' ),
            'get user' );
        my $user_id = decode_json_ok($user_res)->{id};

        my $res = $cb->(
            POST '/user/favorite?access_token=testing',
            Content_Type => 'application/json',
            Content      => encode_json( {
                distribution => 'WWW-Mechanize',
                release      => 'WWW-Mechanize-2.00',
                author       => 'SIMBABQUE',
            } )
        );
        is( $res->code, 201, 'second POST returns 201' );

        my $search = es()->search(
            es_doc_path('favorite'),
            body => {
                query => {
                    bool => {
                        must => [
                            { term => { user         => $user_id } },
                            { term => { distribution => 'WWW-Mechanize' } },
                        ],
                    },
                },
            },
        );
        is( hit_total($search), 2, 'upsert did not create a third doc' );
    };
};

subtest 'DELETE removes all duplicates but preserves other users' => sub {
    test_psgi app, sub {
        my $cb = shift;

        ok( my $user_res = $cb->( GET '/user?access_token=testing' ),
            'get user' );
        my $user_id = decode_json_ok($user_res)->{id};

        my $bot_res = $cb->( GET '/user?access_token=bot' );
        my $bot_id  = decode_json_ok($bot_res)->{id};

        my $res = $cb->(
            POST '/user/favorite?access_token=bot',
            Content_Type => 'application/json',
            Content      => encode_json( {
                distribution => 'WWW-Mechanize',
                release      => 'WWW-Mechanize-1.00',
                author       => 'JESSE',
            } )
        );
        is( $res->code, 201, 'bot user also favorited WWW-Mechanize' );

        my $search = es()->search(
            es_doc_path('favorite'),
            body => {
                query => {
                    bool => {
                        must => [
                            { term => { user         => $user_id } },
                            { term => { distribution => 'WWW-Mechanize' } },
                        ],
                    },
                },
            },
        );
        ok( hit_total($search) >= 2,
            'testing user has duplicate favorites before delete' );

        ok(
            $res = $cb->(
                DELETE '/user/favorite/WWW-Mechanize?access_token=testing'
            ),
            'DELETE duplicate favorites'
        );
        is( $res->code, 200, 'delete returned 200' );

        $search = es()->search(
            es_doc_path('favorite'),
            body => {
                query => {
                    bool => {
                        must => [
                            { term => { user         => $user_id } },
                            { term => { distribution => 'WWW-Mechanize' } },
                        ],
                    },
                },
            },
        );
        is( hit_total($search), 0, 'all favorites for dist deleted' );

        $search = es()->search(
            es_doc_path('favorite'),
            body => {
                query => {
                    bool => {
                        must => [
                            { term => { user         => $bot_id } },
                            { term => { distribution => 'WWW-Mechanize' } },
                        ],
                    },
                },
            },
        );
        is( hit_total($search), 1,
            'favorite for same dist by other user are preserved' );
    };
};

test_psgi app, sub {
    my $cb = shift;

    my $res
        = $cb->( DELETE '/user/favorite/No-Such-Dist?access_token=testing' );
    is( $res->code, 404, 'delete nonexistent favorite returns 404' );
};

done_testing;
