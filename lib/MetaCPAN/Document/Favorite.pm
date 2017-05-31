package MetaCPAN::Document::Favorite;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document;

use DateTime;
use MetaCPAN::Types qw(:all);
use MetaCPAN::Util;

has id => (
    is => 'ro',
    id => [qw(user distribution)],
);

has [qw(author release user distribution)] => (
    is       => 'ro',
    required => 1,
);

=head2 date

L<DateTime> when the item was created.

=cut

has date => (
    is       => 'ro',
    required => 1,
    isa      => 'DateTime',
    default  => sub { DateTime->now },
);

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Document::Favorite::Set;

use strict;
use warnings;

use Moose;
extends 'ElasticSearchX::Model::Document::Set';

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

sub by_user {
    my ( $self, $user, $size ) = @_;
    $size ||= 1000;

    my $favs = $self->es->search(
        index => $self->index->name,
        type  => 'favorite',
        body  => {
            query  => { term => { user => $user } },
            size   => $size,
            fields => [qw( author date distribution )],
            sort   => [      { date    => 'desc' } ],
        }
    );
    return {} unless $favs->{hits}{total};
    my $took = $favs->{took};

    my @favs = map { $_->{fields} } @{ $favs->{hits}{hits} };
    single_valued_arrayref_to_scalar( \@favs );

    # filter out no-latest (backpan only) distributions

    my $latest = $self->es->search(
        index => $self->index->name,
        type  => 'release',
        body  => {
            query => {
                bool => {
                    must => [
                        { term => { status => 'latest' } },
                        {
                            terms => {
                                distribution =>
                                    [ map { $_->{distribution} } @favs ]
                            }
                        },
                    ]
                }
            },
            fields => ['distribution'],
        }
    );
    $took += $latest->{took};

    if ( $latest->{hits}{total} ) {
        my %has_latest = map { $_->{fields}{distribution}[0] => 1 }
            @{ $latest->{hits}{hits} };

        @favs = grep { exists $has_latest{ $_->{distribution} } } @favs;
    }

    return { favorites => \@favs, took => $took };
}

__PACKAGE__->meta->make_immutable;
1;
