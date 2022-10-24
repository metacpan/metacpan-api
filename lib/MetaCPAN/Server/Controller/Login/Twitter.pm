package MetaCPAN::Server::Controller::Login::Twitter;

use Moose;

use Twitter::API;

BEGIN { extends 'MetaCPAN::Server::Controller::Login' }

has [qw(consumer_key consumer_secret)] => (
    is       => 'ro',
    required => 1,
);

sub nt {
    my $self = shift;
    Twitter::API->new_with_traits(
        api_version     => '2',
        consumer_key    => $self->consumer_key,
        consumer_secret => $self->consumer_secret,
    );
}

sub index : Path {
    my ( $self, $c ) = @_;
    my $req = $c->req;
    if ( my $code = $req->parameters->{oauth_verifier} ) {
        my $nt       = $self->nt;
        my $response = $nt->oauth_access_token(
            token        => $c->req->cookies->{twitter_token}->value,
            token_secret => $c->req->cookies->{twitter_token_secret}->value,
            verifier     => $code,
        );

        $c->controller('OAuth2')->redirect( $c, error => 'token' )
            unless ( $response->{oauth_token_secret} );

        $self->update_user(
            $c,
            twitter => $response->{user_id},
            {
                id                  => $response->{user_id},
                name                => $response->{screen_name},
                access_token        => $response->{oauth_token},
                access_token_secret => $response->{oauth_token_secret}
            }
        );
    }
    elsif ( $req->params->{denied} ) {
        $c->controller('OAuth2')->redirect( $c, error => 'denied' );
    }
    else {
        my $nt       = $self->nt;
        my $response = $nt->oauth_request_token(
            callback => $c->uri_for( $self->action_for('index') ) );
        my $url = $nt->oauth_authorization_url(
            {
                oauth_token => $response->{oauth_token},
            }
        );

        my $res = $c->res;
        $res->redirect($url);
        $res->cookies->{twitter_token}
            = { path => '/', value => $response->{oauth_token} };
        $res->cookies->{twitter_token_secret}
            = { path => '/', value => $response->{oauth_token_secret} };
    }
}

1;
