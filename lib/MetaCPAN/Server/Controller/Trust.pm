package MetaCPAN::Server::Controller::Trust;

use strict;
use warnings;

use Moose;
use Try::Tiny;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub find : Path('') : Args(2) {
    my ( $self, $c, $user, $author ) = @_;
    try {
        my $trust = $self->model($c)->raw->get(
            {
                user   => $user,
                author => $author,
            }
        );
        $c->stash( $trust->{_source} || $trust->{fields} );
    }
    catch {
        $c->detach( '/not_found', [$_] );
    };
}

__PACKAGE__->meta->make_immutable;
1;
