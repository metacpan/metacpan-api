package MetaCPAN::Model::Search;

use MetaCPAN::Moose;

use Const::Fast qw( const );
use Log::Contextual qw( :log :dlog );
use MooseX::StrictConstructor;

use Hash::Merge qw( merge );
use List::Util qw( sum uniq );
use MetaCPAN::Types qw( Object Str );
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

has es => (
    is       => 'ro',
    isa      => Object,
    handles  => { _run_query => 'search', },
    required => 1,
);

has index => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

const my $RESULTS_PER_RUN => 200;
const my @ROGUE_DISTRIBUTIONS =>
    qw(kurila perl_debug perl_mlb perl-5.005_02+apache1.3.3+modperl pod2texi perlbench spodcxx Bundle-Everything);

sub _not_rogue {
    my @rogue_dists
        = map { { term => { 'distribution' => $_ } } } @ROGUE_DISTRIBUTIONS;
    return { not => { filter => { or => \@rogue_dists } } };
}

sub search_simple {
    my ( $self, $search_term ) = @_;
    my $es_query = $self->build_query($search_term);
    my $es_results = $self->run_query( file => $es_query );
    return $es_results;
}

sub search_for_first_result {
    my ( $self, $search_term ) = @_;
    my $es_query = $self->build_query($search_term);
    my $es_results = $self->run_query( file => $es_query );
    return unless $es_results->{hits}{total};

    my $data = $es_results->{hits}{hits}[0];
    single_valued_arrayref_to_scalar( $data->{fields} );
    return $data->{fields};
}

=head2 search_web

  search_web( $search_term, $from, $page_size, $collapsed );

- search_term:
   - can be unqualified string e.g. 'paging'
   - can be author e.g: 'author:LLAP'
   - can be module e.g.: 'module:Data::Pageset'
   - can be distribution e.g.: 'dist:Data-Pageset'

- from: where in result set to start, int

- page_size: number of results per page, int

- collapsed: whether to merge results by dist or not

=cut

sub search_web {
    my ( $self, $search_term, $from, $page_size, $collapsed ) = @_;
    $page_size //= 20;
    $from      //= 0;

    # munge the search_term
    # these would be nicer if we had variable-length lookbehinds...
    # Allow q = 'author:LLAP' or 'module:Data::Page' or 'dist:'
    # We are mapping to correct ES fields here - wonder if ANYONE
    # uses these?!?!?!
    $search_term    #
        =~ s{(^|\s)author:([a-zA-Z]+)(?=\s|$)}{$1author:\U$2\E}g;
    $search_term
        =~ s/(^|\s)dist(ribution)?:([\w-]+)(?=\s|$)/$1distribution:$3/g;
    $search_term
        =~ s/(^|\s)module:(\w[\w:]*)(?=\s|$)/$1module.name.analyzed:$2/g;

    my $results
        = $collapsed // $search_term !~ /(distribution|module\.name\S*):/
        ? $self->_search_collapsed( $search_term, $from, $page_size )
        : $self->_search_expanded( $search_term, $from, $page_size );

    return $results;
}

sub _search_expanded {
    my ( $self, $search_term, $from, $page_size ) = @_;

    # Used for distribution and module searches, the limit is included in
    # the query and ES does the right thing (because we are not collapsing
    # results by distribution).
    my $es_query = $self->build_query(
        $search_term,
        {
            size => $page_size,
            from => $from
        }
    );

    my $es_results = $self->run_query( file => $es_query );

    my @distributions = uniq
        map {
        single_valued_arrayref_to_scalar( $_->{fields} );
        $_->{fields}->{distribution}
        } @{ $es_results->{hits}->{hits} };

    # Everything after this will fail (slowly and silently) without results.
    return {} unless @distributions;

    # Lookup favs and extract results from es (adding in favs)
    my $favorites = $self->search_favorites(@distributions);
    my $results = $self->_extract_results_add_favs( $es_results, $favorites );

    # Add descriptions
    my @ids = map { $_->{id} } @{$results};
    my $descriptions = $self->search_descriptions(@ids);

    map { $_->{description} = $descriptions->{results}->{ $_->{id} } }
        @{$results};

    my $return = {
        results => [ map { [$_] } @$results ],
        total   => $es_results->{hits}->{total},
        took => sum( grep {defined} $es_results->{took}, $favorites->{took} ),
        collapsed => \0,
    };
    return $return;
}

sub _search_collapsed {
    my ( $self, $search_term, $from, $page_size ) = @_;

    my $total;
    my @distributions;
    my $es_results;

    my $run  = 1;
    my $hits = 0;
    my $took = 0;

    do {
        # We need to scan enough modules to build up a sufficient number of
        # distributions to fill the results to the number requested
        my $es_query_opts = {
            size => $RESULTS_PER_RUN,
            from => ( $run - 1 ) * $RESULTS_PER_RUN,
        };

        if ( $run == 1 ) {

          # On the first request also fetch the number of total distributions
          # that match the query so that can be reported to the user. There is
          # no need to do it on each iteration though, once is enough.

            $es_query_opts->{aggregations}
                = {
                count => { terms => { size => 999, field => 'distribution' } }
                };
        }

        my $es_query = $self->build_query( $search_term, $es_query_opts );
        $es_results = $self->run_query( file => $es_query );
        $took += $es_results->{took} || 0;

        if ( $run == 1 ) {
            $total
                = @{ $es_results->{aggregations}->{count}->{buckets} || [] };
        }

        $hits = @{ $es_results->{hits}->{hits} || [] };

        # Flatten results down to unique dists
        @distributions = uniq(
            @distributions,
            map {
                single_valued_arrayref_to_scalar( $_->{fields} );
                $_->{fields}->{distribution}
            } @{ $es_results->{hits}->{hits} }
        );

        # Keep track
        $run++;
        } while ( @distributions < $page_size + $from
        && $es_results->{hits}->{total}
        && $es_results->{hits}->{total}
        > $hits + ( $run - 2 ) * $RESULTS_PER_RUN );

    # Avoid "splice() offset past end of array" warning.
    @distributions
        = $from > @distributions
        ? ()
        : splice( @distributions, $from, $page_size );

    # Everything else will fail (slowly and quietly) without distributions.
    return {} unless @distributions;

    # Now that we know which distributions are going to be displayed on the
    # results page, fetch the details about those distributions
    my $es_query = $self->build_query(
        $search_term,
        {
# we will probably never hit that limit, since we are searching in $page_size=20 distributions max
            size  => 5000,
            query => {
                filtered => {
                    filter => {
                        and => [
                            {
                                or => [
                                    map {
                                        { term => { 'distribution' => $_ } }
                                    } @distributions
                                ]
                            }
                        ]
                    }
                }
            }
        }
    );
    my $es_dist_results = $self->run_query( file => $es_query );

    # Look up favs and add to extracted results
    my $favorites = $self->search_favorites(@distributions);
    my $results
        = $self->_extract_results_add_favs( $es_dist_results, $favorites );
    $results = $self->_collapse_results($results);

    # Add descriptions, but only after collapsed as is slow
    my @ids = map { $_->[0]{id} } @$results;
    my $descriptions = $self->search_descriptions(@ids);
    map { $_->[0]{description} = $descriptions->{results}{ $_->[0]{id} } }
        @{$results};

    # Calculate took from sum of all ES searches
    $took += sum( grep {defined} $es_dist_results->{took},
        $favorites->{took}, $descriptions->{took} );

    return {
        results   => $results,
        total     => $total,
        took      => $took,
        collapsed => \1,
    };

}

sub _collapse_results {
    my ( $self, $results ) = @_;
    my %collapsed;
    foreach my $result (@$results) {
        my $distribution = $result->{distribution};
        $collapsed{$distribution}
            = { position => scalar keys %collapsed, results => [] }
            unless ( $collapsed{$distribution} );
        push( @{ $collapsed{$distribution}->{results} }, $result );
    }

    # We return array ref because the results have matching modules
    # grouped by distribution
    return [
        map      { $collapsed{$_}->{results} }
            sort { $collapsed{$a}->{position} <=> $collapsed{$b}->{position} }
            keys %collapsed
    ];
}

sub build_query {
    my ( $self, $search_term, $params ) = @_;
    $params //= {};
    ( my $clean = $search_term ) =~ s/::/ /g;

    my $negative
        = { term => { 'mime' => { value => 'text/x-script.perl' } } };

    my $positive = {
        bool => {
            should => [

                # exact matches result in a huge boost
                {
                    term => {
                        'documentation' => {
                            value => $search_term,
                            boost => 20,
                        }
                    }
                },
                {
                    term => {
                        'module.name' => {
                            value => $search_term,
                            boost => 20,
                        }
                    }
                },

            # take the maximum score from the module name and the abstract/pod
                {
                    dis_max => {
                        queries => [
                            {
                                query_string => {
                                    fields => [
                                        qw(documentation.analyzed^2 module.name.analyzed^2 distribution.analyzed),
                                        qw(documentation.camelcase module.name.camelcase distribution.camelcase)
                                    ],
                                    query                  => $clean,
                                    boost                  => 3,
                                    default_operator       => 'AND',
                                    allow_leading_wildcard => 0,
                                    use_dis_max            => 1,

                                }
                            },
                            {
                                query_string => {
                                    fields =>
                                        [qw(abstract.analyzed pod.analyzed)],
                                    query                  => $clean,
                                    default_operator       => 'AND',
                                    allow_leading_wildcard => 0,
                                    use_dis_max            => 1,

                                }
                            }
                        ]
                    }
                }

            ]
        }
    };

    my $search = merge(
        $params,
        {
            query => {
                filtered => {
                    query => {
                        function_score => {

                            # prefer shorter module names
                            script_score => {
                                script => {
                                    lang => 'groovy',
                                    file => 'prefer_shorter_module_names_400',
                                },
                            },
                            query => {
                                boosting => {
                                    negative_boost => 0.5,
                                    negative       => $negative,
                                    positive       => $positive
                                }
                            }
                        }
                    },
                    filter => {
                        and => [
                            $self->_not_rogue,
                            { term => { status       => 'latest' } },
                            { term => { 'authorized' => 1 } },
                            { term => { 'indexed'    => 1 } },
                            {
                                or => [
                                    {
                                        and => [
                                            {
                                                exists => {
                                                    field => 'module.name'
                                                }
                                            },
                                            {
                                                term =>
                                                    { 'module.indexed' => 1 }
                                            }
                                        ]
                                    },
                                    {
                                        exists => { field => 'documentation' }
                                    },
                                ]
                            }
                        ]
                    }
                }
            },
            _source => [
                "module",
            ],
            fields => [
                qw(
                    abstract.analyzed
                    author
                    authorized
                    date
                    distribution
                    documentation
                    id
                    indexed
                    path
                    pod_lines
                    release
                    status
                    )
            ],
        }
    );

    # Ensure our requested fields are unique so that Elasticsearch doesn't
    # return us the same value multiple times in an unexpected arrayref.
    $search->{fields} = [ uniq @{ $search->{fields} || [] } ];

    return $search;
}

sub run_query {
    my ( $self, $type, $es_query ) = @_;
    return $self->_run_query(
        index       => $self->index,
        type        => $type,
        body        => $es_query,
        search_type => 'dfs_query_then_fetch',
    );
}

sub _build_search_descriptions_query {
    my ( $self, @ids ) = @_;
    my $es_query = {
        query => {
            filtered => {
                query => { match_all => {} },
                filter => { or => [ map { { term => { id => $_ } } } @ids ] }
            }
        },
        fields => [qw(description id)],
        size   => scalar @ids,
    };
    return $es_query;
}

sub search_descriptions {
    my ( $self, @ids ) = @_;
    return {
        descriptions => {},
        took         => 0,
    } unless @ids;

    my $es_query   = $self->_build_search_descriptions_query(@ids);
    my $es_results = $self->run_query( file => $es_query );
    my $results    = {
        results => {
            map { $_->{id} => $_->{description} }
                map { single_valued_arrayref_to_scalar( $_->{fields} ) }
                @{ $es_results->{hits}->{hits} }
        },
        took => $es_results->{took}
    };
    return $results;
}

sub _build_search_favorites_query {
    my ( $self, @distributions ) = @_;

    my $es_query = {
        size  => 0,
        query => {
            filtered => {
                query  => { match_all => {} },
                filter => {
                    or => [
                        map { { term => { 'distribution' => $_ } } }
                            @distributions
                    ]
                }
            }
        },
        aggregations => {
            favorites => {
                terms => {
                    field => 'distribution',
                    size  => scalar @distributions,
                },
            },
        }
    };

    return $es_query;
}

sub search_favorites {
    my ( $self, @distributions ) = @_;
    @distributions = uniq @distributions;

    # If there are no distributions this will build a query with an empty
    # filter and ES will return a parser error... so just skip it.
    return {} unless @distributions;

    my $es_query = $self->_build_search_favorites_query(@distributions);
    my $es_results = $self->run_query( favorite => $es_query );

    my $results = {
        took      => $es_results->{took},
        favorites => {
            map { $_->{key} => $_->{doc_count} }
                @{ $es_results->{aggregations}->{favorites}->{buckets} }
        },
    };
    return $results;
}

sub _extract_results_add_favs {
    my ( $self, $es_results, $favorites ) = @_;

    return [
        map {
            my $res = $_;
            single_valued_arrayref_to_scalar( $res->{fields} );
            +{
                abstract => delete $res->{fields}->{'abstract.analyzed'},
                %{ $res->{fields} },
                %{ $res->{_source} },
                score => $res->{_score},
                favorites =>
                    $favorites->{favorites}{ $res->{fields}->{distribution} },
                }
        } @{ $es_results->{hits}{hits} }
    ];
}

1;

