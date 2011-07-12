package MetaCPAN::Server::Controller::Login::Facebook;

use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller::Login' }
use Facebook::Graph;

has [qw(consumer_key consumer_secret)] => ( is => 'ro', required => 1 );

sub index : Path {
    my ( $self, $c ) = @_;

    my $callback = $c->request->uri->clone;
    $callback->query(undef);
    my $fb = Facebook::Graph->new(
        app_id   => $self->consumer_key,
        secret   => $self->consumer_secret,
        postback => $callback,
    );

    if ( my $code = $c->req->params->{code} ) {
        my $token = eval { $fb->request_access_token($code)->token }
            or $c->controller('OAuth2')->redirect( $c, error => 'token' );
        my $data = $fb->query->find('me')->request->as_hashref;
        $self->update_user( $c, facebook => $data->{id}, $data );
    }
    else {
        my $auth_url = $fb->authorize->uri_as_string;
        $c->res->redirect($auth_url);
    }
}

1;
