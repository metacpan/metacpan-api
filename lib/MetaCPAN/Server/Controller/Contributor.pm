package MetaCPAN::Server::Controller::Contributor;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub get : Path('') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;
    $c->stash_or_detach( $c->model('ESQuery')
            ->contributor->find_release_contributors( $author, $name ) );
}

sub by_pauseid : Path('by_pauseid') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    $c->stash_or_detach(
        $c->model('ESQuery')->contributor->find_author_contributions($pauseid)
    );
}

1;
