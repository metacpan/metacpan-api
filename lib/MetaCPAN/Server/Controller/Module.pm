package MetaCPAN::Server::Controller::Module;

use strict;
use warnings;

use Moose;
use Try::Tiny;

BEGIN { extends 'MetaCPAN::Server::Controller::File' }

has '+type' => ( default => 'file' );

sub get : Path('') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $file = $self->model($c)->raw->find($name);
    if ( !defined $file ) {
        $c->detach( '/not_found', [] );
    }
    try { $c->stash( $file->{_source} || $file->{fields} ) }
        or $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

1;
