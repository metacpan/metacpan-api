package MetaCPAN::Server::Controller::Module;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller::File' }

has '+type' => ( default => 'file' );

sub get : Path('') : Args(1) {
    my ( $self, $c, $name ) = @_;
    eval {
        my $file = $self->model($c)->raw->find($name);
        $c->stash( $file->{_source} || $file->{fields} );
    } or $c->detach( '/not_found', [$@] );
}

1;
