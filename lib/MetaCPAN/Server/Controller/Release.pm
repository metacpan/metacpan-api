package MetaCPAN::Server::Controller::Release;

use strict;
use warnings;

use Moose;
use Try::Tiny;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

__PACKAGE__->config(
    relationships => {
        author => {
            type    => 'Author',
            foreign => 'pauseid',
        }
    }
);

sub find : Path('') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $file = $self->model($c)->raw->find($name);
    if ( !defined $file ) {
        $c->detach( '/not_found', [] );
    }
    try { $c->stash( $file->{_source} || $file->{fields} ) }
        or $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

sub get : Path('') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;
    my $file = $self->model($c)->raw->get(
        {
            author => $author,
            name   => $name,
        }
    );
    if ( !defined $file ) {
        $c->detach( '/not_found', [] );
    }
    try { $c->stash( $file->{_source} || $file->{fields} ) }
        or $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

1;
