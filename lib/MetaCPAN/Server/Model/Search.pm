package MetaCPAN::Server::Model::Search;

use strict;
use warnings;

use Moose;

extends 'MetaCPAN::Server::Model::CPAN';

use Hash::Merge qw( merge );
use List::Util qw( max sum uniq );
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

my $RESULTS_PER_RUN = 200;
my @ROGUE_DISTRIBUTIONS
    = qw(kurila perl_debug perl_mlb perl-5.005_02+apache1.3.3+modperl pod2texi perlbench spodcxx Bundle-Everything);

sub _not_rogue {
    my @rogue_dists
        = map { { term => { 'distribution' => $_ } } } @ROGUE_DISTRIBUTIONS;
    return { not => { filter => { or => \@rogue_dists } } };
}

sub search_expanded {
    my ( $self, $query, $from, $page_size ) = @_;
    $page_size //= 20;
    $from      //= 0;

    # When used for a distribution or module search, the limit is included in
    # thl query and ES does the right thing.
    my $es_query = $self->build_query(
        $query,
        {
            size => $page_size,
            from => $from
        }
    );

    #return $es_query;
    my $data = $self->run_query( file => $es_query );

    my @distributions = uniq
        map {
        single_valued_arrayref_to_scalar( $_->{fields} );
        $_->{fields}->{distribution}
        } @{ $data->{hits}->{hits} };

    # Everything after this will fail (slowly and silently) without results.
    return {} unless @distributions;

    my @ids          = map { $_->{fields}->{id} } @{ $data->{hits}->{hits} };
    my $descriptions = $self->search_descriptions(@ids);
    my $favorites    = $self->search_favorites(@distributions);
    my $results      = $self->_extract_results( $data, $favorites );
    map { $_->{description} = $descriptions->{results}->{ $_->{id} } }
        @{$results};
    my $return = {
        results => [ map { [$_] } @$results ],
        total   => $data->{hits}->{total},
        took => sum( grep {defined} $data->{took}, $favorites->{took} )
    };
    return $return;
}

# was sub search {}
sub build_query {
    my ( $self, $query, $params ) = @_;
    $params //= {};
    ( my $clean = $query ) =~ s/::/ /g;

    my $negative
        = { term => { 'mime' => { value => 'text/x-script.perl' } } };

    my $positive = {
        bool => {
            should => [

                # exact matches result in a huge boost
                {
                    term => {
                        'documentation' => {
                            value => $query,
                            boost => 100
                        }
                    }
                },
                {
                    term => {
                        'module.name' => {
                            value => $query,
                            boost => 100
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
                                                term => {
                                                    'module.indexed' => 1
                                                }
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
            _source => "module",
            fields  => [
                qw(
                    documentation
                    author
                    abstract.analyzed
                    release
                    path
                    status
                    indexed
                    authorized
                    distribution
                    date
                    id
                    pod_lines
                    )
            ],
        }
    );

    # Ensure our requested fields are unique so that Elasticsearch doesn't
    # return us the same value multiple times in an unexpected arrayref.  For
    # example, distribution is listed both above and in ->_search, which calls
    # this function (->search) and gets merged with the query above.
    $search->{fields} = [ uniq @{ $search->{fields} || [] } ];

    return $search;
}

sub run_query {
    my ( $self, $type, $query ) = @_;
    return $self->es->search(
        index => $self->index,
        type  => $type,
        body  => $query,
    );
}

sub _build_search_descriptions_query {
    my ( $self, @ids ) = @_;
    my $query = {
        query => {
            filtered => {
                query  => { match_all => {} },
                filter => {
                    or => [ map { { term => { id => $_ } } } @ids ]
                }
            }
        },
        fields => [qw(description id)],
        size   => scalar @ids,
    };
    return $query;
}

sub search_descriptions {
    my ( $self, @ids ) = @_;
    return {} unless @ids;

    my $query   = $self->_build_search_descriptions_query(@ids);
    my $data    = $self->run_query( file => $query );
    my $results = {
        results => {
            map { $_->{id} => $_->{description} }
                map { single_valued_arrayref_to_scalar( $_->{fields} ) }
                @{ $data->{hits}->{hits} }
        },
        took => $data->{took}
    };
    return $results;
}

sub _build_search_favorites_query {
    my ( $self, @distributions ) = @_;

    my $query = {
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

    return $query;
}

sub search_favorites {
    my ( $self, @distributions ) = @_;
    @distributions = uniq @distributions;

    # If there are no distributions this will build a query with an empty
    # filter and ES will return a parser error... so just skip it.
    return {} unless @distributions;

    my $query = $self->_build_search_favorites_query(@distributions);
    my $data = $self->run_query( favorite => $query );

    my $results = {
        took      => $data->{took},
        favorites => {
            map { $_->{key} => $_->{doc_count} }
                @{ $data->{aggregations}->{favorites}->{buckets} }
        },
    };
    return $results;
}

sub _extract_results {
    my ( $self, $results, $favorites ) = @_;
    return [
        map {
            my $res = $_;
            single_valued_arrayref_to_scalar( $res->{fields} );
            my $dist = $res->{fields}{distribution};
            +{
                %{ $res->{fields} },
                %{ $res->{_source} },
                abstract   => $res->{fields}{'abstract.analyzed'},
                score      => $res->{_score},
                favorites  => $favorites->{favorites}{$dist},
                myfavorite => $favorites->{myfavorites}{$dist},
                }
        } @{ $results->{hits}{hits} }
    ];
}

1;

