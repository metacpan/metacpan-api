package MetaCPAN::Server::Controller::Login::Google;

use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller::Login' }
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;

has [qw( consumer_key consumer_secret )] => ( is => 'ro', required => 1 );

sub index : Path {
    my ($self, $c) = @_;
    my $req = $c->req;

    if (my $code = $c->req->params->{code}) {
        my $ua  = LWP::UserAgent->new;
        my $token_res = $ua->request(
            POST 'https://accounts.google.com/o/oauth2/token',
            [
                code          => $code,
                client_id     => $self->consumer_key,
                client_secret => $self->consumer_secret,
                redirect_uri  => $c->uri_for($self->action_for('index')),
                grant_type    => 'authorization_code',
            ]
        );

        my $token_info = eval { decode_json($token_res->content) } || {};

        $c->controller('OAuth2')->redirect($c, error => $token_info->{error})
            if defined $token_info->{error};

        my $token = $token_info->{access_token};
        $c->controller('OAuth2')->redirect($c, error => 'token')
            unless $token;

        my $user_res = $ua->request(
            GET "https://www.googleapis.com/oauth2/v1/userinfo?access_token=$token");
        my $user = eval { decode_json($user_res->content) } || {};
        $self->update_user($c, google => $user->{id}, $user);
    }
    else {
        my $url = URI->new('https://accounts.google.com/o/oauth2/auth');
        $url->query_form(
            client_id     => $self->consumer_key,
            response_type => 'code',
            redirect_uri  => $c->uri_for($self->action_for('index')),
            scope         => 'https://www.googleapis.com/auth/userinfo.profile',
        );
        $c->res->redirect($url);
    }
}

1;
