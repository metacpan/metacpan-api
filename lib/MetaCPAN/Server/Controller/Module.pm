package MetaCPAN::Server::Controller::Module;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

BEGIN { extends 'MetaCPAN::Server::Controller::File' }

has '+type' => ( default => 'file' );

sub get : Path('') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $file
        = $c->model('ESQuery')->file->find_module( $name, $c->req->fields );
    if ( !defined $file ) {
        $c->detach( '/not_found', [] );
    }
    $c->stash($file);
}

__PACKAGE__->meta->make_immutable();
1;
