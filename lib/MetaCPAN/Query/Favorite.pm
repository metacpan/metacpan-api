package MetaCPAN::Query::Favorite;

use MetaCPAN::Moose;

use Log::Contextual    qw( :log );
use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util     qw( hit_total paginate );

with 'MetaCPAN::Query::Role::Common';

sub agg_by_distributions {
    my ( $self, $distributions, $user ) = @_;
    return {
        favorites   => {},
        myfavorites => {},
        took        => 0,
        }
        unless $distributions && @$distributions;

    my $body = {
        size  => 0,
        query => {
            terms => { distribution => $distributions }
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
                    filter       => { term => { user => $user } },
                    aggregations => {
                        entries => {
                            terms => { field => 'distribution' }
                        }
                    }
                }
                )
            : (),
        }
    };

    my $ret = $self->es->search( es_doc_path('favorite'), body => $body, );

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
    my ( $self, $user, $page, $size ) = @_;
    my $from;
    ( $page, $size, $from ) = paginate( $page, $size );

    return +{ favorites => [], took => 0, total => 0 }
        unless defined $page;

    # Step 1: get ALL favorited distribution names for this user via agg
    my $all_favs = $self->es->search(
        es_doc_path('favorite'),
        body => {
            size         => 0,
            query        => { term => { user => $user } },
            aggregations => {
                dists => {
                    terms => {
                        field => 'distribution',

                        # No single user has more than ~1500 favorites
                        # in practice, so 5000 gives plenty of headroom.
                        size => 5000,
                    },
                },
            },
        }
    );
    return +{ favorites => [], took => 0, total => 0 }
        unless $all_favs->{aggregations}{dists}{buckets}
        && @{ $all_favs->{aggregations}{dists}{buckets} };

    if ( my $other = $all_favs->{aggregations}{dists}{sum_other_doc_count} ) {
        log_warn {
            "Favorite agg for user $user truncated: $other docs excluded"
        };
    }

    my $took = $all_favs->{took};

    my @all_dists
        = map { $_->{key} } @{ $all_favs->{aggregations}{dists}{buckets} };

    # Step 2: find which of those distributions are non-backpan
    my $non_backpan = $self->es->search(
        es_doc_path('release'),
        body => {
            size  => 0,
            query => {
                bool => {
                    must => [
                        { terms => { status       => [qw( cpan latest )] } },
                        { terms => { distribution => \@all_dists } },
                    ]
                }
            },
            aggregations => {
                dists => {
                    terms => {
                        field => 'distribution',
                        size  => scalar(@all_dists),
                    },
                },
            },
        }
    );
    $took += $non_backpan->{took};

    my @valid_dists
        = map { $_->{key} } @{ $non_backpan->{aggregations}{dists}{buckets} };

    return +{ favorites => [], took => $took, total => 0 }
        unless @valid_dists;

    # Step 3: paginate over only valid (non-backpan) favorites,
    # collapsing on distribution to deduplicate
    my $favs = $self->es->search(
        es_doc_path('favorite'),
        body => {
            query => {
                bool => {
                    must => [
                        { term  => { user         => $user } },
                        { terms => { distribution => \@valid_dists } },
                    ]
                }
            },
            collapse => { field => 'distribution' },
            _source  => [qw( author date distribution )],

            # Sort by distribution name; within each collapsed group,
            # keep the oldest favorite (earliest date wins).
            sort => [ 'distribution', { date => 'asc' } ],

            # With collapse, size is the number of unique distributions
            # returned, not the number of raw favorite documents.
            size => $size,
            from => $from,
        }
    );
    $took += $favs->{took};

    my @favs = map { $_->{_source} } @{ $favs->{hits}{hits} };

    return {
        favorites => \@favs,
        took      => $took,
        total     => hit_total($favs),
    };
}

sub leaderboard {
    my $self = shift;

    my $body = {
        size         => 0,
        query        => { match_all => {} },
        aggregations => {
            leaderboard => {
                terms => {
                    field => 'distribution',
                    size  => 100,
                },
            },
            totals => {
                cardinality => {
                    field => 'distribution',
                },
            },
        },
    };

    my $ret = $self->es->search( es_doc_path('favorite'), body => $body, );

    return {
        leaderboard => $ret->{aggregations}{leaderboard}{buckets},
        total       => $ret->{aggregations}{totals}{value},
        took        => $ret->{took},
    };
}

sub recent {
    my ( $self, $page, $size ) = @_;
    my $from;
    ( $page, $size, $from ) = paginate( $page, $size );

    return +{ favorites => [], took => 0, total => 0 }
        unless defined $page;

    my $favs = $self->es->search(
        es_doc_path('favorite'),
        body => {
            size  => $size,
            from  => $from,
            query => { match_all => {} },
            sort  => [ { 'date' => { order => 'desc' } } ]
        }
    );

    my @favs = map { $_->{_source} } @{ $favs->{hits}{hits} };

    return +{
        favorites => \@favs,
        took      => $favs->{took},
        total     => hit_total($favs),
    };
}

sub users_by_distribution {
    my ( $self, $distribution ) = @_;

    my $favs = $self->es->search(
        es_doc_path('favorite'),
        body => {
            query   => { term => { distribution => $distribution } },
            _source => ['user'],
            size    => 1000,
        }
    );
    return {} unless hit_total($favs);

    my @plusser_users = map { $_->{_source}{user} } @{ $favs->{hits}{hits} };

    return { users => \@plusser_users };
}

__PACKAGE__->meta->make_immutable;
1;
