package MetaCPAN::Server::Controller::Search::Autocomplete;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach(
        $self->model($c)->autocomplete( $c->req->param("q") ) );
}

sub suggest : Local : Path('/suggest') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach(
        $self->model($c)->autocomplete_suggester( $c->req->param("q") ) );
}

1;
