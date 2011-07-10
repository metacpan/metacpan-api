package MetaCPAN::Server::Controller::Login::GitHub;

use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller::Login' }
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;

has [qw(consumer_key consumer_secret redirect_uri)] =>
    ( is => 'ro', required => 1 );

sub index : Path {
    my ( $self, $c ) = @_;

    if ( my $code = $c->req->params->{code} ) {
        my $ua  = LWP::UserAgent->new;
        my $res = $ua->request(
            POST 'https://github.com/login/oauth/access_token',
            [   client_id     => $self->consumer_key,
                redirect_uri  => $self->redirect_uri,
                client_secret => $self->consumer_secret,
                code          => $code,
            ]
        );
        if ( $res->content =~ /^error/ ) {
            return $self->unauthorized;
        }
        ( my $token = $res->content ) =~ s/^access_token=//;
        $token =~ s/&.*$//;
        my $extra_res = $ua->request(
            GET "https://api.github.com/user?access_token=$token" );
        my $extra = eval { decode_json( $extra_res->content ) } || {};
        $self->update_user( $c, github => $extra->{id}, $extra );
    }
    else {
        $c->res->redirect(
            'https://github.com/login/oauth/authorize?client_id='
                . $self->consumer_key );
    }
}

1;
