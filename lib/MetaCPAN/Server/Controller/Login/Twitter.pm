package MetaCPAN::Server::Controller::Login::Twitter;

use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller::Login' }
use LWP::UserAgent;
use HTTP::Request::Common;
use Net::Twitter;
use JSON;

has [qw(consumer_key consumer_secret)] => ( is => 'ro', required => 1 );

sub nt {
    my $self = shift;
    Net::Twitter->new(
        traits          => [ 'API::REST', 'OAuth' ],
        consumer_key    => $self->consumer_key,
        consumer_secret => $self->consumer_secret,
    );
}

sub index : Path {
    my ( $self, $c ) = @_;
    my $req = $c->req;
    if ( my $code = $req->parameters->{oauth_verifier} ) {
        my $nt = $self->nt;
        $nt->request_token( $c->req->cookies->{twitter_token}->value );
        $nt->request_token_secret(
            $c->req->cookies->{twitter_token_secret}->value );

        my ( $access_token, $access_token_secret, $user_id, $screen_name )
            = $nt->request_access_token( verifier => $code );
        $c->controller('OAuth2')->redirect( $c, error => 'token' )
            unless ($access_token);
        $self->update_user(
            $c,
            twitter => $user_id,
            {   id                  => $user_id,
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
        my $nt  = $self->nt;
        my $url = $nt->get_authorization_url(
            callback => $c->uri_for( $self->action_for('index') ) );
        my $res = $c->res;
        $res->redirect($url);
        $res->cookies->{twitter_token}
            = { path => '/', value => $nt->request_token };
        $res->cookies->{twitter_token_secret}
            = { path => '/', value => $nt->request_token_secret };
    }
}

1;
