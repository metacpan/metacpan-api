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

    if (my $code = $c->req->param->{code}) {
        my $ua  = LWP::UserAgent->new
        my $res = $ua->request(
            POST 'https://accounts.google.com/o/outh2/auth',
            [
                client_id     => $self->consumer_key,
                client_secret => $self->consumer_secret,
                redirect_uri  => $c->uri_for($self->action_for('index')),
                code          => $code,
            ]
        );
        $c->controller('OAuth2')->redirect($c, error => $1)
            if $res->content =~ /^error=(.*)$/;
        (my $token = $res->content) =~ s/^access_token=//;
        $c->controller('OAuth2')->redirect($c, error => 'token')
            unless $token;
        $token =~ s/&.*$//;

        my $extra_res = $ua->request(
            GET "https://accounts.google.com/oauth2/v1/tokeninfo?access_token=$token");
        my $extra = eval { decode_json($extra_res->content) } || {};
        $self->update_user($c, google => $extra->{user_id}, $extra);
    }
    else {
        my $url = URI->new('https://accounts.google.com/o/oauth2/auth');
        $url->query_form(
            client_id     => $self->consumer_key,
            response_type => 'code',
            redirect_uri  => $c->uri_for($self->action_for('index')),
            scope         => 'https://www.googleapis.com/auth/userinfo.email',
        );
        $c->res->redirect($url);
    }
}

1;
