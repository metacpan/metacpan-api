package MetaCPAN::Server::Controller::Login;

use strict;
use warnings;

use Cpanel::JSON::XS qw( decode_json encode_json );
use Moose;

BEGIN { extends 'Catalyst::Controller' }

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->cdn_never_cache(1);

    # Store params in a temporary cookie so we can keep track of them.
    # This should include `client_id` (metacpan env) and `choice` (provider).
    if ( $c->req->params->{client_id} ) {
        $c->res->cookies->{oauth_tmp} = {
            value   => encode_json( $c->req->parameters ),
            path    => '/',
            expires => '+7d'
        };
    }

    return 1;
}

sub index : Path {
    my ( $self, $c ) = @_;
    my @login = map { "<li><a href=\"/login/" . lc($_) . "\">$_</a></li>" }
        sort map /^Login::(.*)/, $c->controllers;
    $c->res->content_type('text/html');
    $c->res->body(qq{<pre><h1>Login via</h1><ul>@login</ul></pre>});
}

sub update_user {
    my ( $self, $c, $type, $id, $data ) = @_;
    my $model = $c->model('User::Account');
    my $user  = $model->find( { name => $type, key => $id } );
    unless ($user) {
        $user = $model->get( $c->user->id )
            if ( $c->session->{__user} );
        $user ||= $model->new_document;
        $user->add_identity( { name => $type, key => $id, extra => $data } );
        $user->clear_looks_human;    # rebuild
        $user->put( { refresh => 1 } );
    }
    $c->authenticate( { user => $user } );

    # Find the cookie we set earlier.
    if ( my $cid = $c->req->cookie('oauth_tmp') ) {

        # Expire the cookie (tell the browser to remove it).
        $cid->expires('-1y');

        # Pass the params to the oauth controller so it can use them
        # to redirect the user to the appropriate place.
        # NOTE: This controller is `lib/Catalyst/Plugin/OAuth2/Provider.pm`.
        $c->res->redirect(
            $c->uri_for( '/oauth2/authorize', decode_json( $cid->value ) ) );
        $c->res->cookies->{oauth_tmp} = $cid;
    }

    # Without the cookie we don't know where to send them.
    else {
        $c->res->redirect('/user');
    }
    $c->detach;

}

1;
