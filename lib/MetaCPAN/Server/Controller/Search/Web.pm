package MetaCPAN::Server::Controller::Search::Web;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

# Kill default actions provided by our stupid Controller base class
sub get { }
sub all { }

# returns the contents of the first result of a query
sub first : Chained('/search/index') : PathPart('first') : Args(0) {
    my ( $self, $c ) = @_;
    my $args = $c->req->params;

    my $model   = $c->model('Search');
    my $results = $model->search_for_first_result( $args->{q} );

    $c->stash_or_detach($results);
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
