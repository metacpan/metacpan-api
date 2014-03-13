package Plack::Session::Store::ElasticSearch;

use strict;
use warnings;

use base 'Plack::Session::Store';

use List::MoreUtils qw();
use Plack::Util::Accessor qw(es index type property);

sub new {
    my ( $class, %params ) = @_;
    bless {
        index    => 'user',
        type     => 'session',
        property => 'id',
        %params
    } => $class;
}

sub fetch {
    my ( $self, $session_id ) = @_;
    return undef unless ($session_id);
    my $data = eval {
        $self->es->get(
            index  => $self->index,
            type   => $self->type,
            id     => $session_id,
            fields => [ '_parent', '_source' ]
        );
    } || return undef;
    $data->{_parent} = delete $data->{fields}->{_parent};
    return $data;
}

sub store {
    my ( $self, $session_id, $session ) = @_;
    $self->es->index(
        index  => $self->index,
        type   => $self->type,
        id     => $session_id || undef,
        parent => $session->{_parent} || "",
        data => keys %$session ? $session->{_source} : { $self->type => {} },
        refresh => 1,
    );
}

sub remove {
    my ( $self, $session_id ) = @_;
    $self->es->delete(
        index   => $self->index,
        type    => $self->type,
        id      => $session_id,
        refresh => 1,
    );
}

1;
