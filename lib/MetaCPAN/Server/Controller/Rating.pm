package MetaCPAN::Server::Controller::Rating;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub by_distributions : Path('by_distributions') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach( {
        took          => 0,
        total         => 0,
        distributions => {},
    } );
}

sub get : Path('') : Args(1) {
    my ( $self, $c ) = @_;
    $c->detach('/not_found');
}

sub _mapping : Path('_mapping') : Args(0) {
    my ( $self, $c ) = @_;
    $c->detach('/not_found');
}

sub find : Path('_search') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach( {
        timed_out => \0,
        took      => 0,
        _shards   => {
            successful => 0,
            total      => 0,
            failed     => 0,
        },
        hits => {
            total     => 0,
            hits      => [],
            max_score => undef,
        }
    } );
}

sub all : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('find');
}

1;
