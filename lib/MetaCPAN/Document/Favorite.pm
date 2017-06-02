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
    $size ||= 250;

    my $favs = $self->es->search(
        index => $self->index->name,
        type  => 'favorite',
        body  => {
            query  => { term => { user => $user } },
            fields => [qw( author date distribution )],
            sort   => ['distribution'],
            size   => $size,
        }
    );
    return {} unless $favs->{hits}{total};
    my $took = $favs->{took};

    my @favs = map { $_->{fields} } @{ $favs->{hits}{hits} };

    single_valued_arrayref_to_scalar( \@favs );

    # filter out backpan only distributions

    my $no_backpan = $self->es->search(
        index => $self->index->name,
        type  => 'release',
        body  => {
            query => {
                bool => {
                    must => [
                        { terms => { status => [qw( cpan latest )] } },
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
            size   => scalar(@favs),
        }
    );
    $took += $no_backpan->{took};

    if ( $no_backpan->{hits}{total} ) {
        my %has_no_backpan = map { $_->{fields}{distribution}[0] => 1 }
            @{ $no_backpan->{hits}{hits} };

        @favs = grep { exists $has_no_backpan{ $_->{distribution} } } @favs;
    }

    return { favorites => \@favs, took => $took };
}

sub recent {
    my ( $self, $page, $size ) = @_;
    $page //= 1;
    $size //= 100;

    my $favs = $self->es->search(
        index => $self->index->name,
        type  => 'favorite',
        body  => {
            size  => $size,
            from  => ( $page - 1 ) * $size,
            query => { match_all => {} },
            sort  => [ { 'date' => { order => 'desc' } } ]
        }
    );
    return {} unless $favs->{hits}{total};

    my @favs = map { $_->{_source} } @{ $favs->{hits}{hits} };

    return +{
        favorites => \@favs,
        took      => $favs->{took},
        total     => $favs->{total}
    };
}

__PACKAGE__->meta->make_immutable;
1;
