package MetaCPAN::Server::Controller::Mirror;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub search : Path('search') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->search( $c->req->param('q') );
    return unless $data;
    $c->stash($data);
}

1;
