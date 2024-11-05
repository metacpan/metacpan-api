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
        my $favorite = $self->model($c)->raw->get( {
            user         => $user,
            distribution => $distribution
        } );
        $c->stash( $favorite->{_source}
                || single_valued_arrayref_to_scalar( $favorite->{fields} ) );
    } or $c->detach( '/not_found', [$@] );
}

sub by_user : Path('by_user') : Args(1) {
    my ( $self, $c, $user ) = @_;
    $c->stash_or_detach(
        $self->model($c)->by_user( $user, $c->req->param('size') || 250 ) );
}

sub users_by_distribution : Path('users_by_distribution') : Args(1) {
    my ( $self, $c, $distribution ) = @_;
    $c->stash_or_detach(
        $self->model($c)->users_by_distribution($distribution) );
}

sub recent : Path('recent') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach(
        $self->model($c)->recent(
            $c->req->param('page') || 1,
            $c->req->param('page_size') || $c->req->param('size') || 100,
        )
    );
}

sub leaderboard : Path('leaderboard') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach( $self->model($c)->leaderboard() );
}

sub agg_by_distributions : Path('agg_by_distributions') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach(
        $self->model($c)->agg_by_distributions(
            $c->read_param('distribution'),
            $c->req->param('user')    # optional
        )
    );
}

__PACKAGE__->meta->make_immutable;
1;
