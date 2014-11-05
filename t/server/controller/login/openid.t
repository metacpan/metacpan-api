use strict;
use warnings;
use utf8;

use JSON qw( decode_json );
use MetaCPAN::Server::Test;
use Test::More;
use Test::OpenID::Server;

my $openid_server = Test::OpenID::Server->new;
my $url           = $openid_server->started_ok('start server');

test_psgi app, sub {
    my $cb = shift;
    require MetaCPAN::Server::Controller::Login::OpenID;

    MetaCPAN::Server::Controller::Login::OpenID->_ua->resolver
        ->whitelisted_hosts( [ 'localhost', '127.0.0.1' ] );

    ok( my $res = $cb->( GET "/login/openid?openid_identifier=$url/test" ),
        'login with test URL' );
    like( $res->header('location'),
        qr/openid.server/, 'get correct OpenID server url' );
    ok( $res = $cb->( GET "/login/openid?openid_identifier=$url/unknown" ),
        'get unknown ID page' );
    my $body = decode_json( $res->content );
    like( $body->{error}, qr/no_identity_server/,
        'get descriptive error for unknown ID' );
};

done_testing();
