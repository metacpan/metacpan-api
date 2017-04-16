package MetaCPAN::Server::Role::Starring;

use strict;
use warnings;

use Moose::Role;

sub index_POST {
    my ( $self, $c ) = @_;
    my $req  = $c->req;
    my $star = $c->model('CPAN::Stargazer')->put(
        {
            author  => $req->data->{author},
            module  => $req->data->{module},
            release => $req->data->{release},
            user    => $c->user->id,
        },
        { refresh => 1 }
    );
    $self->status_created(
        $c,
        location => $c->uri_for(
            join( q{/}, '/stargazer', $star->user, $star->module )
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
        $self->status_ok( $c, entity => $star->meta->get_data($star) );
    }
    else {
        $self->status_not_found( $c, message => 'Entity could not be found' );
    }
}

1;
