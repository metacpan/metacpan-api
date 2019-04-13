package MetaCPAN::Server::Controller::Login::Twitter;

use strict;
use warnings;

use HTTP::Request::Common;
use Cpanel::JSON::XS;
use LWP::UserAgent;
use Moose;
use Twitter::API;

BEGIN { extends 'MetaCPAN::Server::Controller::Login' }

has [qw(consumer_key consumer_secret)] => (
    is       => 'ro',
    required => 1,
);

sub twitter_api {
    my $self = shift;
    Twitter::API->new(
        consumer_key    => $self->consumer_key,
        consumer_secret => $self->consumer_secret,
    );
}

sub index : Path {
    my ( $self, $c ) = @_;
    my $req = $c->req;
    if ( my $code = $req->parameters->{oauth_verifier} ) {
        my $api = $self->twitter_api;
        $api->request_token( $c->req->cookies->{twitter_token}->value );
        $api->request_token_secret(
            $c->req->cookies->{twitter_token_secret}->value );

        my ( $access_token, $access_token_secret, $user_id, $screen_name )
            = $api->request_access_token( verifier => $code );
        $c->controller('OAuth2')->redirect( $c, error => 'token' )
            unless ($access_token);
        $self->update_user(
            $c,
            twitter => $user_id,
            {
                id                  => $user_id,
                name                => $screen_name,
                access_token        => $access_token,
                access_token_secret => $access_token_secret
            }
        );
    }
    elsif ( $req->params->{denied} ) {
        $c->controller('OAuth2')->redirect( $c, error => 'denied' );
    }
    else {
        my $api  = $self->twitter_api;
        my $token = $api->oauth_request_token(
            callback => $c->uri_for( $self->action_for('index') ) );
        my $url = $api->oauth_authentication_url(
        );
        get_authorization_url(
        my $res = $c->res;
        $res->redirect($url);
        $res->cookies->{twitter_token}
            = { path => '/', value => $api->request_token };
        $res->cookies->{twitter_token_secret}
            = { path => '/', value => $api->request_token_secret };
    }
}

1;
