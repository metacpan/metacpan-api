package MetaCPAN::Server::Controller::Search::WebLike;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub get : Chained('/search/index') : PathPart('web_like') : Args(0) {
    my ( $self, $c ) = @_;
    my $args = $c->req->params;

    my $model = $c->model('Search');
    my $query = $model->build_query( $args->{q} );

    $c->stash( $model->run_query($query) );
}

1;
