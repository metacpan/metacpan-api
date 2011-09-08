package Catalyst::Plugin::OAuth2::Provider;
use Moose::Role;
use CatalystX::InjectComponent;

after 'setup_components' => sub {
    my $class = shift;
    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'Catalyst::Plugin::OAuth2::Provider::Controller',
        as        => 'Controller::OAuth2',
    );
};

1;

package Catalyst::Plugin::OAuth2::Provider::Controller;

use Moose;
BEGIN { extends 'Catalyst::Controller' }

use Digest::SHA1;
use JSON;
use URI;

has login   => ( is => 'ro' );
has clients => ( is => 'ro' );

sub COMPONENT {
    my $self = shift;
    my ( $app, $config ) = @_;
    $config = $self->merge_config_hashes( $app->config->{'OAuth2::Provider'},
        $config );
    return $self->SUPER::COMPONENT( $app, $config );
}

sub authorize : Local {
    my ( $self, $c ) = @_;
    my $params = $c->req->query_parameters;
    if ($params->{choice}
        && (  !$c->user_exists
            || $c->user_exists
            && !$c->user->has_identity( $params->{choice} ) )
        )
    {
        $c->res->redirect(
            $c->uri_for( "/login/$params->{choice}", undef, $params ) );
        $c->detach;
    }
    elsif ( !$c->user_exists ) {
        $c->res->redirect( $c->uri_for( "/login", undef, $params ) );
        $c->detach;
    }
    my ( $response_type, $client_id, $redirect_uri, $scope, $state )
        = @$params{qw(response_type client_id redirect_uri scope state)};
    $self->redirect( $c, error => 'invalid_request' )
        unless ($client_id);
    $self->redirect( $c, error => 'unauthorized_client' )
        unless ( $self->clients->{$client_id} );
    $redirect_uri = $self->clients->{$client_id}->{redirect_uri}->[0];
    $self->redirect( $c, error => 'invalid_request' )
        unless ($redirect_uri);
    $response_type ||= 'code';
    my $uri  = URI->new($redirect_uri);
    my $code = $self->_build_code;
    $uri->query_form( { code => $code, $state ? ( state => $state ) : () } );
    $c->user->code($code);
    $c->user->put( { refresh => 1 } );
    $c->res->redirect($uri);
}

sub access_token : Local {
    my ( $self, $c ) = @_;
    my $params = $c->req->query_parameters;
    my ( $grant_type, $client_id, $code, $redirect_uri, $client_secret )
        = @$params{qw(grant_type client_id code redirect_uri client_secret)};
    $grant_type ||= 'authorization_code';
    $self->bad_request( $c,
        invalid_request => 'client_id query parameter is required' )
        unless ($client_id);
    $self->bad_request( $c,
        unauthorized_client => 'client_id does not exist' )
        unless ( $self->clients->{$client_id} );
    $self->bad_request( $c,
        unauthorized_client => 'client_secret does not match' )
        unless ( $self->clients->{$client_id}->{secret} eq $client_secret );

    $redirect_uri = $self->clients->{$client_id}->{redirect_uri}->[0];
    $self->bad_request( $c,
        invalid_request => 'redirect_uri query parameter is required' )
        unless ($redirect_uri);
    $self->bad_request( $c,
        invalid_request => 'code query parameter is required' )
        unless ($code);
    my $user = $c->model('User::Account')->find_code($code);
    $self->bad_request( $c, access_denied => 'the code is invalid' )
        unless ($user);

    my ($access_token) = map { $_->{token} }
        grep { $_->{client} eq $client_id } @{ $user->access_token };
    unless ($access_token) {
        $access_token = $self->_build_code;
        $user->add_access_token(
            { token => $access_token, client => $client_id } );
    }
    $user->clear_token;
    $user->put( { refresh => 1 } );

    $c->res->content_type('application/json');
    $c->res->body(
        encode_json(
            { access_token => $access_token, token_type => 'bearer' }
        )
    );

}

sub bad_request {
    my ( $self, $c, $type, $message ) = @_;
    $c->res->code(500);
    $c->res->content_type('application/json');
    $c->res->body(
        encode_json( { error => $type, error_description => $message } ) );
    $c->detach;
}

sub _build_code {
    my $digest = Digest::SHA1::sha1_base64( rand() . $$ . {} . time );
    $digest =~ tr/[+\/]/-_/;
    return $digest;
}

sub redirect {
    my ( $self, $c, $type, $message ) = @_;
    my $clients = $self->clients;
    my $params  = $c->req->params;
    if ( my $cid = $c->req->cookie('oauth_tmp') ) {
        eval { $params = decode_json( $cid->value ) };
        $cid->expires('-1y');
        $c->res->cookies->{oauth_tmp} = $cid;
    }
    my ( $client, $redirect_uri ) = @$params{qw(client_id redirect_uri)};
    # we don't trust the user's redirect uri
    $redirect_uri = $self->clients->{$client}->{redirect_uri}->[0]
        if($client);

    if ($redirect_uri) {
        $c->res->redirect( $redirect_uri . "?$type=$message" );
    }
    else {
        $c->res->body( encode_json( { $type => $message } ) );
        $c->res->content_type('application/json');
    }
    $c->detach;
}

1;
