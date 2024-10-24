package MetaCPAN::Script::Session;

use strict;
use warnings;

use Moose;

use DateTime           ();
use MetaCPAN::ESConfig qw( es_doc_path );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

sub run {
    my $self = shift;

    my $scroll = $self->es->scroll_helper(
        size   => 10_000,
        scroll => '1m',
        es_doc_path('session'),
    );

    my $bulk = $self->es->bulk_helper( es_doc_path('session'),
        max_count => 10_000 );

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

Purges user sessions. we iterate over the sessions for the time being and
perform bulk delete.

=cut
