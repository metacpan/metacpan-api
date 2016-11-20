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

sub web : Chained('/search/index') : PathPart('web') : Args(0) {
    my ( $self, $c ) = @_;
    my $args = $c->req->params;

    my $model   = $c->model('Search');
    my $results = $model->search_web( @{$args}{qw( q from size collapsed )} );

    $c->stash($results);
}

1;
