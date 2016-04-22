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
        body =>
            { query => { filtered => { query => { match_all => {} }, }, }, },
    );

    my $bulk = $self->es->bulk_helper(
        index     => 'user',
        type      => 'session',
        max_count => 10_000
    );

    my $cutoff = DateTime->now->subtract( months => 1 )->epoch;

    while ( my $search = $scroll->next ) {

        if ( $search->{_source}->{__updated} < $cutoff ) {
            $bulk->delete( { id => $search->{_id} } );
        }

    }

    $bulk->flush;

}

__PACKAGE__->meta->make_immutable;
1;

=pod

Purges user sessions.  The timestamp field doesn't appear to get populated in
the session type, so we just iterate over the sessions for the time being and
perform bulk delete.

=cut
