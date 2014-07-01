package MetaCPAN::Server::Controller::Stargazer;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub find : Path('') : Args(2) {
    my ( $self, $c, $user, $module ) = @_;
    eval {
        my $stargazer = $self->model($c)->raw->get(
            {
                user   => $user,
                module => $module
            }
        );
        $c->stash( $stargazer->{_source} || $stargazer->{fields} );
    } or $c->detach( '/not_found', [$@] );
}

__PACKAGE__->meta->make_immutable;
1;
