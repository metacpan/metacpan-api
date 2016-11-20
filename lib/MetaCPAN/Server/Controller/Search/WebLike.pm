package MetaCPAN::Server::Controller::Search::WebLike;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub simple : Chained('/search/index') : PathPart('simple') : Args(0) {
    my ( $self, $c ) = @_;
    my $args = $c->req->params;

    my $model = $c->model('Search');
    my $query = $model->build_query( $args->{q} );

    $c->stash( $model->run_query( file => $query ) );
}

sub expanded : Chained('/search/index') : PathPart('expanded') : Args(0) {
    my ( $self, $c ) = @_;
    my $args  = $c->req->params;
    my $query = $args->{q};

    my $model   = $c->model('Search');
    my $results = $model->search_expanded($query);

    $c->stash($results);
}

sub collapsed : Chained('/search/index') : PathPart('collapsed') : Args(0) {
    my ( $self, $c ) = @_;
    my $args  = $c->req->params;
    my $query = $args->{q};

    my $model   = $c->model('Search');
    my $results = $model->search_collapsed($query);

    $c->stash($results);
}

1;
