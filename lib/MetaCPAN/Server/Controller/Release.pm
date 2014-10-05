package MetaCPAN::Server::Controller::Release;

use strict;
use warnings;

use Moose;

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
        $c->detach( '/not_found', [$@] );
    }
    else {
        eval { $c->stash( $file->{_source} || $file->{fields} ); }
            or $c->detach( '/fields_not_found', [$@] );
    }
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
        $c->detach( '/not_found', [$@] );
    }
    else {
        eval { $c->stash( $file->{_source} || $file->{fields} ); }
            or $c->detach( '/fields_not_found', [$@] );
    }
}

1;
