package MetaCPAN::Server::Controller::Favorite;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';
with 'MetaCPAN::Server::Role::ES::Query';

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
        $c->stash( $favorite->{_source} || $favorite->{fields} );
    } or $c->detach( '/not_found', [$@] );
}

# endpoint: /favorite/by_user?user=<csv_user_ids>[&fields=<csv_fields>][&sort=<csv_sort>][&size=N]
sub by_user : Path('by_user') : Args(0) {
    my ( $self, $c ) = @_;
    my @users = split /,/ => $c->req->parameters->{user};
    $self->es_by_key_vals( $c, 'user', \@users );
}

__PACKAGE__->meta->make_immutable;
1;
