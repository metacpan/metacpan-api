package MetaCPAN::Script::Session;

use strict;
use warnings;

use DateTime;
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

sub run {
    my $self = shift;

    my $scroll = $self->es()->scroll_helper(
        size   => 10_000,
        scroll => '1m',
        index  => 'user',
        type   => 'session',
        query  => { filtered => { query => { match_all => {} }, }, },
    );

    my @delete;

    my $cutoff = DateTime->now->subtract( months => 1 )->epoch;
    while ( my $search = $scroll->next ) {
        if ( $search->{_source}->{__updated} < $cutoff ) {
            push @delete, $search->{_id};
        }

        if ( scalar @delete >= 10_000 ) {
            $self->delete(@delete);
            @delete = ();
        }

    }
    $self->delete(@delete) if @delete;
}

sub delete {
    my $self   = shift;
    my @delete = @_;

    $self->es->bulk(
        index   => 'user',
        type    => 'session',
        actions => [ map { +{ delete => { id => $_ } } } @delete ],
    );
}

__PACKAGE__->meta->make_immutable;
1;

=pod

Purges user sessions.  The timestamp field doesn't appear to get populated in
the session type, so we just iterate over the sessions for the time being and
perform bulk delete.

=cut
