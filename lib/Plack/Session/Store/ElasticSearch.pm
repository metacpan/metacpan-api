package Plack::Session::Store::ElasticSearch;
use strict;
use warnings;
use base 'Plack::Session::Store';
use List::MoreUtils qw();

use Plack::Util::Accessor qw(es index type property);

sub new {
    my ( $class, %params ) = @_;
    bless { index    => 'user',
            type     => 'session',
            property => 'id',
            %params
    } => $class;
}

sub fetch {
    my ( $self, $session_id ) = @_;
    $self->find($session_id)->{_source} || {};
}

sub store {
    my ( $self, $session_id, $session ) = @_;
    my $old = $self->find($session_id);
    my $sessions = $old->{ $self->property } || [];
    $sessions = [$sessions] unless ( ref $sessions eq 'ARRAY' );
    push( @$sessions, $session_id );
    @$sessions = List::MoreUtils::uniq @$sessions;
    $self->put( $old->{_id},
                  {  %{ $old->{_source} || {} },
                     %{ $session || {} },
                     $self->property => $sessions
                  } );
}

sub remove {
    my ( $self, $session_id ) = @_;
    my $session = $self->find($session_id);
    my $sessions = $session->{ $self->property } || [];
    $sessions = [$sessions] unless ( ref $sessions eq 'ARRAY' );
    @$sessions = [ grep { $_ ne $session_id } @$sessions ];
    $self->put( $session->{_id},
                  {  %{ $session->{_source} },
                     %$session,
                     $self->property => $sessions
                  } );
}

sub put {
    my ( $self, $id, $data ) = @_;
    $self->es->index( index => $self->index,
                      type  => $self->type,
                      id => $id || undef,
                      data    => $data,
                      refresh => 1, );
}

sub fqfn {
    my $self = shift;
    return join( '.', $self->type, $self->property );
}

sub find {
    my ( $self, $session_id ) = @_;
    my $res = $self->es->search(
              index => $self->index,
              type  => $self->type,
              query  => { match_all => {} },
              filter => {
                  term => {
                      $self->fqfn =>
                        $session_id
                  }
              },
              size => 1, );
    return $res->{hits}->{hits}->[0] || {};
}

1;
