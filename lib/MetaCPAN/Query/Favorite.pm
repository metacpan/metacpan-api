package MetaCPAN::Query::Favorite;

use MetaCPAN::Moose;

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

with 'MetaCPAN::Query::Role::Common';

sub agg_by_distributions {
    my ( $self, $distributions, $user ) = @_;
    return unless $distributions;

    my $body = {
        size  => 0,
        query => {
            terms => { 'distribution' => $distributions }
        },
        aggregations => {
            favorites => {
                terms => {
                    field => 'distribution',
                    size  => scalar @{$distributions},
                },
            },
            $user
            ? (
                myfavorites => {
                    filter       => { term => { 'user' => $user } },
                    aggregations => {
                        enteries => {
                            terms => { field => 'distribution' }
                        }
                    }
                }
                )
            : (),
        }
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'favorite',
        body  => $body,
    );

    my %favorites = map { $_->{key} => $_->{doc_count} }
        @{ $ret->{aggregations}{favorites}{buckets} };

    my %myfavorites;
    if ($user) {
        %myfavorites = map { $_->{key} => $_->{doc_count} }
            @{ $ret->{aggregations}{myfavorites}{entries}{buckets} };
    }

    return {
        favorites   => \%favorites,
        myfavorites => \%myfavorites,
        took        => $ret->{took},
    };
}

sub by_user {
    my ( $self, $user, $size ) = @_;
    $size ||= 250;

    my $favs = $self->es->search(
        index => $self->index_name,
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
        index => $self->index_name,
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

sub leaderboard {
    my $self = shift;

    my $body = {
        size         => 0,
        query        => { match_all => {} },
        aggregations => {
            leaderboard =>
                { terms => { field => 'distribution', size => 600 }, },
        },
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'favorite',
        body  => $body,
    );

    my @leaders
        = @{ $ret->{aggregations}{leaderboard}{buckets} }[ 0 .. 99 ];

    return {
        leaderboard => \@leaders,
        took        => $ret->{took},
        total       => $ret->{total}
    };
}

sub recent {
    my ( $self, $page, $size ) = @_;
    $page //= 1;
    $size //= 100;

    my $favs = $self->es->search(
        index => $self->index_name,
        type  => 'favorite',
        body  => {
            size  => $size,
            from  => ( $page - 1 ) * $size,
            query => { match_all => {} },
            sort  => [ { 'date' => { order => 'desc' } } ]
        }
    );

    my @favs = map { $_->{_source} } @{ $favs->{hits}{hits} };

    return +{
        favorites => \@favs,
        took      => $favs->{took},
        total     => $favs->{hits}{total}
    };
}

sub users_by_distribution {
    my ( $self, $distribution ) = @_;

    my $favs = $self->es->search(
        index => $self->index_name,
        type  => 'favorite',
        body  => {
            query   => { term => { distribution => $distribution } },
            _source => ['user'],
            size    => 1000,
        }
    );
    return {} unless $favs->{hits}{total};

    my @plusser_users = map { $_->{_source}{user} } @{ $favs->{hits}{hits} };

    single_valued_arrayref_to_scalar( \@plusser_users );

    return { users => \@plusser_users };
}

__PACKAGE__->meta->make_immutable;
1;
