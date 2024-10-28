package MetaCPAN::Server::User;

use strict;
use warnings;

use Moose;

extends 'Catalyst::Authentication::User';

has obj => (
    is     => 'ro',
    isa    => 'MetaCPAN::Model::User::Account',
    writer => '_set_obj',
);

sub get_object { shift->obj }

sub store {'Catalyst::Authentication::Plugin::Store::Proxy'}

sub for_session {
    shift->obj->id;
}

sub from_session {
    my ( $self, $c, $id ) = @_;
    my $user = $c->model('ESModel')->doc('account')->get($id);
    $self->_set_obj($user) if ($user);
    return $user ? $self : undef;
}

sub find_user {
    my ( $self, $auth ) = @_;
    $self->_set_obj( $auth->{user} );
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
1;
