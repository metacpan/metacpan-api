package MetaCPAN::Server::Controller::Search::AuthorSearch;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'author' );

sub get : Local : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    my $model = $self->model($c);
    $model = $model->fields( [qw(name pauseid gravatar_url)] )
        unless $model->fields;
    my $data = $model->authorsearch( $c->req->param('q') )->raw;
    $c->stash( $data->all );
}

1;
