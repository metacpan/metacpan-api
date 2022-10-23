package MetaCPAN::Server::Controller::User::Favorite;

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
    my $favorite = $c->model('CPAN::Favorite')->put(
        {
            user         => $c->user->id,
            author       => $req->data->{author},
            release      => $req->data->{release},
            distribution => $req->data->{distribution},
            author       => $req->data->{author},
        },
        { refresh => 1 }
    );
    $self->status_created(
        $c,
        location => $c->uri_for( join( '/',
            '/favorite', $favorite->user, $favorite->distribution ) ),
        entity => $favorite->meta->get_data($favorite)
    );
}

sub index_DELETE {
    my ( $self, $c, $distribution ) = @_;
    my $favorite = $c->model('CPAN::Favorite')
        ->get( { user => $c->user->id, distribution => $distribution } );
    if ($favorite) {
        $favorite->delete( { refresh => 1 } );
        $self->status_ok( $c,
            entity => $favorite->meta->get_data($favorite) );
    }
    else {
        $self->status_not_found( $c, message => 'Entity could not be found' );
    }
}

1;
