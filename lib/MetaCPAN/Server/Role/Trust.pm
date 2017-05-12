package MetaCPAN::Server::Role::Trust;

use strict;
use warnings;

use Moose::Role;

sub index_POST {
    my ( $self, $c ) = @_;
    my $req   = $c->req;
    my $trust = $c->model('CPAN::Trust')->put(
        {
            author => $req->data->{author},
            user   => $c->user->id,
        },
        { refresh => 1 }
    );
    $self->status_created(
        $c,
        location => $c->uri_for(
            join( q{/}, '/trust', $trust->user, $trust->author )
        ),
        entity => $trust->meta->get_data($trust)
    );
}

sub index_DELETE {
    my ( $self, $c, $author ) = @_;
    my $trust = $c->model('CPAN::Trust')
        ->get( { user => $c->user->id, author => $author } );
    if ($trust) {
        $trust->delete( { refresh => 1 } );
        $self->status_ok( $c, entity => $trust->meta->get_data($trust) );
    }
    else {
        $self->status_not_found( $c, message => 'Entity could not be found' );
    }
}

1;
