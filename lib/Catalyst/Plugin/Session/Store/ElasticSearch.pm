package Catalyst::Plugin::Session::Store::ElasticSearch;

# ABSTRACT: Store session data in ElasticSearch

use Moose;
extends 'Catalyst::Plugin::Session::Store';
use List::MoreUtils qw();
use MooseX::Types::ElasticSearch qw(:all);

has _session_es => (
    required => 1,
    is       => 'rw',
    coerce   => 1,
    isa      => ES,
    default  => sub { shift->_session_plugin_config->{servers} || ':9200' }
);
has _session_es_index => (
    required => 1,
    is       => 'rw',
    default  => sub { shift->_session_plugin_config->{index} || 'user' }
);
has _session_es_type => (
    required => 1,
    is       => 'rw',
    default  => sub { shift->_session_plugin_config->{type} || 'session' }
);

sub get_session_data {
    my ( $self, $key ) = @_;
    if ( my ($sid) = $key =~ /^\w+:(.*)/ ) {
        my $data = eval {
            $self->_session_es->get(
                index => $self->_session_es_index,
                type  => $self->_session_es_type,
                id    => $sid,
            );
        } || return undef;
        if ( $key =~ /^expires:/ ) {
            return $data->{_source}->{_expires};
        }
        else {
            return $data->{_source};
        }
    }
}

sub store_session_data {
    my ( $self, $key, $session ) = @_;
    if ( my ($sid) = $key =~ /^session:(.*)/ ) {
        $session->{_expires} = $self->session_expires;
        $self->_session_es->index(
            index   => $self->_session_es_index,
            type    => $self->_session_es_type,
            id      => $sid,
            body    => $session,
            refresh => 1,
        );
    }
}

sub delete_session_data {
    my ( $self, $key ) = @_;
    if ( my ($sid) = $key =~ /^session:(.*)/ ) {
        eval {
            $self->_session_es->delete(
                index   => $self->_session_es_index,
                type    => $self->_session_es_type,
                id      => $sid,
                refresh => 1,
            );
        };
    }
}

sub delete_expired_sessions { }

1;

=head1 SYNOPSIS

 $ curl -XPUT localhost:9200/user
 $ curl -XPUT localhost:9200/user/session/_mapping -d '{"session":{"dynamic":false}}'

 use Catalyst qw(
     Session
     Session::Store::ElasticSearch
 );
 
 # defaults
 MyApp->config(
     'Plugin::Session' => {
         servers => ':9200',
         index   => 'user',
         type    => 'session',
     } );

=head1 DESCRIPTION

This module will store session data in ElasticSearch. ElasticSearch
is a fast and reliable document store.

=head1 CONFIGURATION

=head2 es

Connection string to an ElasticSearch instance. Can either be a port
on localhost (e.g. C<:9200>), a full address to the ElasticSearch
server (e.g. C<127.0.0.1:9200>), an ArrayRef of connection strings or
a HashRef that initialized an L<ElasticSearch> instance.

=head2 index

The ElasticSearch index to use. Defaults to C<user>.

=head2 type

The ElasticSearch type to use. Defaults to C<session>.
