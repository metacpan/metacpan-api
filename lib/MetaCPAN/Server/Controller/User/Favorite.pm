package MetaCPAN::Server::Controller::User::Favorite;

use Moose;
BEGIN { extends 'Catalyst::Controller::REST' }

sub auto : Private {
    my ( $self, $c ) = @_;
    ( $c->stash->{pause} ) = $c->user->get_identities('pause');
}

sub index : Path : ActionClass('REST') {
}

sub index_POST {
    my ( $self, $c ) = @_;
    my $pause    = $c->stash->{pause};
    my $req      = $c->req;
    my $favorite = $c->model('CPAN::Favorite')->put(
        {   user         => $pause->key,
            author       => $req->data->{author},
            release      => $req->data->{release},
            distribution => $req->data->{distribution},
            author       => $req->data->{author},
        },
        { refresh => 1 }
    );
    $self->status_created(
        $c,
        location => $c->uri_for( '/favorite/' . $favorite->_id ),
        entity   => $favorite->meta->get_data($favorite)
    );
}

sub index_DELETE {
    my ( $self, $c, $id ) = @_;
    my $favorite = $c->model('CPAN::Favorite')->get($id);
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
