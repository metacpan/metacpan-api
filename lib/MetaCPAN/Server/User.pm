package MetaCPAN::Server::User;

use Moose;
extends 'Catalyst::Authentication::User';

has obj => ( is => 'rw', isa => 'MetaCPAN::Model::User::Account' );

sub get_object { shift->obj }

sub store {'Catalyst::Authentication::Plugin::Store::Proxy'}

sub for_session {
    shift->obj->id;
}

sub from_session {
    my ( $self, $c, $id ) = @_;
    my $user = $c->model('User::Account')->get($id);
    $self->obj($user) if ($user);
    return $user ? $self : undef;
}

sub find_user {
    my ( $self, $auth ) = @_;
    $self->obj( $auth->{user} );
    return $self;
}

sub supports {
    my ( $self, @feature ) = @_;
    return 1 if ( grep { $_ eq 'session' } @feature );
}

sub data {
    my $self = shift;
    return $self->obj->meta->get_data( $self->obj );
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
