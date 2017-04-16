package MetaCPAN::Server::Controller::Stargazer;

use strict;
use warnings;

use Moose;
use Try::Tiny;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub find : Path('') : Args(2) {
    my ( $self, $c, $user, $module ) = @_;
    try {
        my $stargazer = $self->model($c)->raw->get(
            {
                user   => $user,
                module => $module,
            }
        );
        $c->stash( $stargazer->{_source} || $stargazer->{fields} );
    }
    catch {
        $c->detach( '/not_found', [$_] );
    };
}

__PACKAGE__->meta->make_immutable;
1;
