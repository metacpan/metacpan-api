package MetaCPAN::Server::Controller::User::Favorite;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( true false );

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
    my $data     = $c->req->data;
    my $favorite = $c->model('CPAN::Favorite')->put(
        {
            user         => $c->user->id,
            author       => $data->{author},
            release      => $data->{release},
            distribution => $data->{distribution},
        },
        { refresh => true }
    );
    $c->purge_author_key( $data->{author} )     if $data->{author};
    $c->purge_dist_key( $data->{distribution} ) if $data->{distribution};
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
        $favorite->delete( { refresh => true } );
        $c->purge_author_key( $favorite->author )
            if $favorite->author;
        $c->purge_dist_key($distribution);
        $self->status_ok( $c,
            entity => $favorite->meta->get_data($favorite) );
    }
    else {
        $self->status_not_found( $c, message => 'Entity could not be found' );
    }
}

1;
