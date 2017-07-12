package MetaCPAN::Server::Controller::Rating;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub by_distributions : Path('by_distributions') : Args(0) {
    my ( $self, $c ) = @_;

    my $data = $self->model($c)
        ->by_distributions( $c->read_param('distribution') );

    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

1;
