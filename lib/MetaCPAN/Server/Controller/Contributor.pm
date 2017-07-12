package MetaCPAN::Server::Controller::Contributor;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( digest );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub get : Path('') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;

    my $data = $self->model($c)->find_release_contributors( $author, $name );

    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

sub by_pauseid : Path('by_pauseid') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;

    my $data = $self->model($c)->find_author_contributions($pauseid);

    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

1;
