package MetaCPAN::Server::Controller::Search::Web;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

# Kill default actions provided by our stupid Controller base class
sub get { }
sub all { }

# The simple search avoids most of the input and output aggregation and munging and is therefore easier to reason about for say search optimization.

sub simple : Chained('/search/index') : PathPart('simple') : Args(0) {
    my ( $self, $c ) = @_;
    my $args = $c->req->params;

    my $model   = $c->model('Search');
    my $results = $model->search_simple( $args->{q} );

    $c->stash($results);
}

# returns the contents of the first result of a query similar to
# the one done by 'search_simple'
sub first : Chained('/search/index') : PathPart('first') : Args(0) {
    my ( $self, $c ) = @_;
    my $args = $c->req->params;

    my $model   = $c->model('Search');
    my $results = $model->search_for_first_result( $args->{q} );

    $c->stash($results) if $results;
}

# The web endpoint is the primary one, this handles the front-end's user-facing search

sub web : Chained('/search/index') : PathPart('web') : Args(0) {
    my ( $self, $c ) = @_;
    my $args = $c->req->params;

    my $model   = $c->model('Search');
    my $results = $model->search_web( @{$args}{qw( q from size collapsed )} );

    $c->stash($results);
}

1;
