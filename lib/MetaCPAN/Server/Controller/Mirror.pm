package MetaCPAN::Server::Controller::Mirror;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub search : Path('search') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach(
        $c->model('ESQuery')->mirror->search( $c->req->param('q') ) );
}

1;
