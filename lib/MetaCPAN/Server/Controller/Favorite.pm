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

# endpoint: /favorite/by_user
# params:   user=<id>[&user=<id2>]...
# optional: [&fields=<field>][&sort=<sort_key>][&size=N][&page=N]
sub by_user : Path('by_user') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->by_user( $c->req );
    $c->stash($data);
}

# endpoint: /favorite/by_distribution
# params:   distribution=<distribution>
# optional: [&fields=<field>][&sort=<sort_key>][&size=N][&page=N]
sub by_distribution : Path('by_distribution') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->by_distribution( $c->req );
    $c->stash($data);
}

# endpoint: /favorite/leaderboard
# optional: [&size=N]
sub leaderboard : Path('leaderboard') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->leaderboard( $c->req );
    $c->stash($data);
}

# endpoint: /favorite/plusser_by_user
# params:   user=<user>
# optional: [&fields=<field>][&sort=<sort_key>][&size=N][&page=N]
sub plusser_by_user : Path('plusser_by_user') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $c->model('CPAN::Author')->raw->plusser_by_user( $c->req );
    $c->stash($data);
}

# endpoint: /favorite/recent
# optional: [&fields=<field>][&sort=<sort_key>][&size=N][&page=N]
sub recent : Path('recent') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->recent( $c->req );
    $c->stash($data);
}

# endpoint: /favorite/agg_dists_user
# optional: [&fields=<field>][&sort=<sort_key>][&size=N][&page=N]
sub agg_dists_user : Path('agg_dists_user') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->agg_dists_user( $c->req );
    $c->stash($data);
}

__PACKAGE__->meta->make_immutable;
1;
