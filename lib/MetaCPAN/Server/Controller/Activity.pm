package MetaCPAN::Server::Controller::Activity;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub get : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $c->model('CPAN::Release')->activity( $c->req->params );

    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

__PACKAGE__->meta->make_immutable;
1;
