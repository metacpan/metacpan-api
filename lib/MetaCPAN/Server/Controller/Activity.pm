package MetaCPAN::Server::Controller::Activity;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub get : Path('') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash_or_detach(
        $c->model('CPAN::Release')->activity( $c->req->params ) );
}

__PACKAGE__->meta->make_immutable;
1;
