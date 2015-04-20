use strict;
use warnings;
use utf8;

package # Test::Routine's run_me (in main) doesn't mix well with Test::Aggregate.
    t::server::controller::login::openid;

use JSON qw( decode_json );
use MetaCPAN::Server::Test;
use Test::More;
use Test::OpenID::Server;
use Test::Routine;
use Test::Routine::Util;

with qw(
    MetaCPAN::Tests::UserAgent
);

my $openid_server = Test::OpenID::Server->new;
my $url           = $openid_server->started_ok('start server');

sub fix_localhost_uri {
    my $uri = shift;

    # The dev vm make it localhost, but on travis it becomes `.localdomain`.
    $uri =~ s{^(\w+://localhost)\.localdomain([:/])}{$1$2};
    $uri;
}

test authorization => sub {
    my $self = shift;

    # Set client_id to get cookie.
    my %params = (
        openid_identifier => "$url/test",
        client_id         => 'metacpan.dev',
    );
    my $uri_params = URI->new;
    $uri_params->query_form(%params);

    ok( $self->request( GET '/login/openid?' . $uri_params->query ),
        'login with test URL' );

    like fix_localhost_uri( $self->redirect_uri ),
        qr{\Q$url\E/openid.server}, 'get correct OpenID server url';

    $self->follow_redirect;

    like $self->redirect_uri,
        qr{/login/openid .+ openid\.mode}x,
        'returns to openid controller';

    $self->follow_redirect;

    my $authed_uri    = $self->redirect_uri;
    my %authed_params = $authed_uri->query_form;

    is $authed_params{$_}, $params{$_}, "preserved $_ param"
        for sort keys %params;

    is $authed_uri->path, '/oauth2/authorize',
        'redirect to internal oauth provider';

    $self->follow_redirect;

    my $final_url = $self->redirect_uri;

    is $final_url->host_port, 'localhost:5001',
        'final redirect goes to web ui';
    is $final_url->path, '/login', 'login to ui';
    ok { $final_url->query_form }->{code}, 'request has code param';
};

test unknown_provider => sub {
    my $self = shift;
    my $res;

    ok(
        $res
            = $self->cb->(
            GET "/login/openid?openid_identifier=$url/unknown" ),
        'get unknown ID page'
    );
    my $body = decode_json( $res->content );
    like( $body->{error}, qr/no_identity_server/,
        'get descriptive error for unknown ID' );
};

test_psgi app, sub {
    my $cb = shift;
    require MetaCPAN::Server::Controller::Login::OpenID;

    MetaCPAN::Server::Controller::Login::OpenID->_ua->resolver
        ->whitelisted_hosts( [ 'localhost', '127.0.0.1' ] );

    run_me(
        {
            cb => $cb,
        }
    );
};

done_testing();
