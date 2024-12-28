package MetaCPAN::Server::Controller::Search::Autocomplete;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach(
        $c->model('ESQuery')->file->autocomplete( $c->req->param("q") ) );
}

sub suggest : Local : Path('/suggest') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach( $c->model('ESQuery')
            ->file->autocomplete_suggester( $c->req->param("q") ) );
}

1;
