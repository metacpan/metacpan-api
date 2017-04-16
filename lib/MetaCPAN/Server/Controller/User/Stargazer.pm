package MetaCPAN::Server::Controller::User::Stargazer;

use strict;
use warnings;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

with 'MetaCPAN::Server::Role::Starring';

sub auto : Private {
    my ( $self, $c ) = @_;
    unless ( $c->user->looks_human ) {
        $self->status_forbidden( $c,
            message => 'please complete the turing test' );
        return 0;
    }
    return 1;
}

sub index : Path : ActionClass('REST') {
}

1;
