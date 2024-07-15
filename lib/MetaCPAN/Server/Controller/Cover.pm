package MetaCPAN::Server::Controller::Cover;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub get : Path('') : Args(1) {
    my ( $self, $c, $release ) = @_;
    $c->stash_or_detach( $self->model($c)->find_release_coverage($release) );
}

1;
