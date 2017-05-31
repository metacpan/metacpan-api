package MetaCPAN::Server::Controller::Favorite;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub find : Path('') : Args(2) {
    my ( $self, $c, $user, $distribution ) = @_;

    # Do this for now and we don't have to worry about purging it
    $c->cdn_never_cache(1);

    eval {
        my $favorite = $self->model($c)->raw->get(
            {
                user         => $user,
                distribution => $distribution
            }
        );
        $c->stash( $favorite->{_source}
                || single_valued_arrayref_to_scalar( $favorite->{fields} ) );
    } or $c->detach( '/not_found', [$@] );
}

sub by_user : Path('by_user') : Args(1) {
    my ( $self, $c, $user ) = @_;
    my $size = $c->req->param('size') || 250;
    my $data = $self->model($c)->raw->by_user( $user, $size );
    $data or return;
    $c->stash($data);
}

__PACKAGE__->meta->make_immutable;
1;
