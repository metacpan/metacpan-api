package MetaCPAN::Server::Controller::Login;

use Moose;
BEGIN { extends 'Catalyst::Controller' }
use Facebook::Graph;
use JSON;

sub auto : Private {
    my ( $self, $c ) = @_;
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
        sort grep {s/^Login:://} $c->controllers;
    $c->res->content_type('text/html');
    $c->res->body(qq{<pre><h1>Login via</h1><ul>@login</ul></pre>});
}

sub update_user {
    my ( $self, $c, $type, $id, $data ) = @_;
    my $model = $c->model('User::Account');
    my $user = $model->find( { name => $type, key => $id } );
    unless ($user) {
        $user = $model->get( $c->user->id )
            if ( $c->session->{__user} );
        $user ||= $model->new_document;
        $user->add_identity( { name => $type, key => $id, extra => $data } );
        $user->clear_looks_human;    # rebuild
        $user->put( { refresh => 1 } );
    }
    $c->authenticate( { user => $user } );
    if ( my $cid = $c->req->cookie('oauth_tmp') ) {
        $cid->expires('-1y');
        $c->res->redirect(
            $c->uri_for(
                '/oauth2/authorize', undef, decode_json( $cid->value )
            )
        );
        $c->res->cookies->{oauth_tmp} = $cid;
    }
    else {
        $c->res->redirect('/user');
    }
    $c->detach;

}

1;
