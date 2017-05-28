package MetaCPAN::Server::Controller::Activity;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub get : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $c->model('CPAN::Release')->raw->activity( $c->req->params );
    return unless $data;
    $c->stash($data);
}

__PACKAGE__->meta->make_immutable;
1;
