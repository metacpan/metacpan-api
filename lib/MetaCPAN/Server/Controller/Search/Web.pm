package MetaCPAN::Server::Controller::Search::Web;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

# Kill default actions provided by our stupid Controller base class
sub get { }
sub all { }

sub simple : Chained('/search/index') : PathPart('simple') : Args(0) {
    my ( $self, $c ) = @_;
    my $args = $c->req->params;

    my $model   = $c->model('Search');
    my $results = $model->search_simple( $args->{q} );

    $c->stash($results);
}

sub web : Chained('/search/index') : PathPart('web') : Args(0) {
    my ( $self, $c ) = @_;
    my $args = $c->req->params;

    my $model   = $c->model('Search');
    my $results = $model->search_web( @{$args}{qw( q from size collapsed )} );

    $c->stash($results);
}

1;
