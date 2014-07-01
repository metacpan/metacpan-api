package MetaCPAN::Server::Controller::User::Stargazer;

use strict;
use warnings;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

sub auto : Private {
    my ( $self, $c ) = @_;
    unless ( $c->user->looks_human ) {
        $self->status_forbidden( $c,
            message => 'please complete the turing test' );
        return 0;
    }
    else {
        return 1;
    }
}

sub index : Path : ActionClass('REST') {
}

sub index_POST {
    my ( $self, $c ) = @_;
    my $pause    = $c->stash->{pause};
    my $req      = $c->req;
    my $star     = $c->model('CPAN::Stargazer')->put(
        {
            user         => $c->user->id,
            author       => $req->data->{author},
            release      => $req->data->{release},
            module	 => $req->data->{module},
            author       => $req->data->{author},
        },
        { refresh => 1 }
    );
    $self->status_created(
        $c,
        location => $c->uri_for(
            join(
                '/', '/stargazer', $star->user, $star->module
            )
        ),
        entity => $star->meta->get_data($star)
    );
}

sub index_DELETE {
    my ( $self, $c, $module ) = @_;
    my $star = $c->model('CPAN::Stargazer')
        ->get( { user => $c->user->id, module => $module } );
    if ($star) {
        $star->delete( { refresh => 1 } );
        $self->status_ok( $c,
            entity => $star->meta->get_data($star) );
    }
    else {
        $self->status_not_found( $c, message => 'Entity could not be found' );
    }
}

1;
