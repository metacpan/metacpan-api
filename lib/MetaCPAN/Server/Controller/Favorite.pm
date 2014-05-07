package MetaCPAN::Server::Controller::Favorite;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub find : Path('') : Args(2) {
    my ( $self, $c, $user, $distribution ) = @_;
    eval {
        my $favorite = $self->model($c)->raw->get(
            {
                user         => $user,
                distribution => $distribution
            }
        );
        $c->stash( $favorite->{_source} || $favorite->{fields} );
    } or $c->detach( '/not_found', [$@] );
}

__PACKAGE__->meta->make_immutable;
1;
