package Catalyst::Plugin::Session::Store::ElasticSearch;

use Moose;
extends 'Catalyst::Plugin::Session::Store';
use List::MoreUtils qw();
use MooseX::Types::ElasticSearch qw(:all);

has session_es =>
    ( required => 1, is => 'ro', coerce => 1, default => ':9200', isa => ES );
has session_es_index => ( required => 1, is => 'ro', default => 'user' );
has session_es_type  => ( required => 1, is => 'ro', default => 'session' );
has session_es_property => ( required => 1, is => 'ro', default => 'id' );

sub get_session_data {
    my ( $self, $session_id ) = @_;
    return undef unless ($session_id);
    my $data = eval {
        $self->session_es->get(
            index  => $self->session_es_index,
            type   => $self->session_es_type,
            id     => $session_id,
        );
    } || return undef;
    return $data->{_source};
}

sub store_session_data {
    my ( $self, $session_id, $session ) = @_;
    $session = { $self->session_es_type => {} } unless(ref $session);
    $self->session_es->index(
        index  => $self->session_es_index,
        type   => $self->session_es_type,
        id     => $session_id || undef,
        parent => $session->{__user} || "",
        data   => $session,
        refresh => 1,
    );
}

sub delete_session_data {
    my ( $self, $session_id ) = @_;
    eval {
        $self->session_es->delete(
            index   => $self->session_es_index,
            type    => $self->session_es_type,
            id      => $session_id,
            refresh => 1,
        );
    };
}

sub delete_expired_sessions { }

1;

=head1 SYNOPSIS
