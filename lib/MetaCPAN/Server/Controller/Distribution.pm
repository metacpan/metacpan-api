package MetaCPAN::Server::Controller::Distribution;

use strict;
use warnings;
use namespace::autoclean;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub river_data_by_dist : Path('river') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    $c->stash_or_detach(
        $c->model('ESQuery')->distribution->get_river_data_by_dist($dist) );
}

sub river_data_by_dists : Path('river') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach(
        $c->model('ESQuery')->distribution->get_river_data_by_dists(
            $c->read_param('distribution')
        )
    );
}

__PACKAGE__->meta->make_immutable;
1;
