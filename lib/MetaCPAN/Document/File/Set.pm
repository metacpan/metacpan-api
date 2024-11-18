package MetaCPAN::Document::File::Set;

use Moose;

use List::Util                qw( max );
use MetaCPAN::ESConfig        qw( es_doc_path );
use MetaCPAN::Query::Favorite ();
use MetaCPAN::Query::File     ();
use MetaCPAN::Query::Release  ();
use MetaCPAN::Util            qw( true false );

extends 'ElasticSearchX::Model::Document::Set';

has query_favorite => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Favorite',
    lazy    => 1,
    builder => '_build_query_favorite',
    handles => [qw< agg_by_distributions >],
);

sub _build_query_favorite {
    my $self = shift;
    return MetaCPAN::Query::Favorite->new( es => $self->es );
}

my @ROGUE_DISTRIBUTIONS = qw(
    Acme-DependOnEverything
    Bundle-Everything
    kurila
    perl-5.005_02+apache1.3.3+modperl
    perlbench
    perl_debug
    pod2texi
    spodcxx
);

sub find {
    my ( $self, $module ) = @_;

    my $query = {
        bool => {
            must => [
                { term => { indexed    => true } },
                { term => { authorized => true } },
                { term => { status     => 'latest' } },
                {
                    bool => {
                        should => [
                            { term => { documentation => $module } },
                            {
                                nested => {
                                    path  => "module",
                                    query => {
                                        bool => {
                                            must => [
                                                {
                                                    term => { "module.name" =>
                                                            $module }
                                                },
                                                {
                                                    bool => { should =>
                                                            [
                                                            { term =>
                                                                    { "module.authorized"
                                                                        => true
                                                                    } },
                                                            { exists =>
                                                                    { field =>
                                                                        'module.associated_pod'
                                                                    } },
                                                            ],
                                                    }
                                                },
                                            ],
                                        },
                                    },
                                }
                            },
                        ]
                    }
                },
            ],
        },
    };

    my $res = $self->es->search(
        es_doc_path('file'),
        search_type => 'dfs_query_then_fetch',
        body        => {
            query => $query,
            sort  => [
                '_score',
                { 'version_numified' => { order => 'desc' } },
                { 'date'             => { order => 'desc' } },
                { 'mime'             => { order => 'asc' } },
                { 'stat.mtime'       => { order => 'desc' } }
            ],
            _source => [
                qw( documentation module.indexed module.authoried module.name )
            ],
            size => 100,
        },
    );

    my @candidates = @{ $res->{hits}{hits} };

    my ($file) = grep {
        grep { $_->{indexed} && $_->{authorized} && $_->{name} eq $module }
            @{ $_->{module} || [] }
    } grep { !$_->{documentation} || $_->{documentation} eq $module }
        @candidates;

    $file ||= shift @candidates;
    return $file ? $self->get( $file->{_id} ) : undef;
}

sub find_pod {
    my ( $self, $name ) = @_;
    my $file = $self->find($name);
    return $file unless ($file);
    my ($module)
        = grep { $_->indexed && $_->authorized && $_->name eq $name }
        @{ $file->module || [] };
    if ( $module && ( my $pod = $module->associated_pod ) ) {
        my ( $author, $release, @path ) = split( /\//, $pod );
        return $self->get( {
            author  => $author,
            release => $release,
            path    => join( '/', @path ),
        } );
    }
    else {
        return $file;
    }
}

sub documented_modules {
    my ( $self, $release ) = @_;
    return $self->query( {
        bool => {
            must => [
                { term   => { release => $release->{name} } },
                { term   => { author  => $release->{author} } },
                { exists => { field   => "documentation" } },
                {
                    bool => {
                        should => [
                            {
                                bool => {
                                    must => [
                                        {
                                            exists =>
                                                { field => 'module.name' }
                                        },
                                        {
                                            term =>
                                                { 'module.indexed' => true }
                                        },
                                    ],
                                }
                            },
                            {
                                bool => {
                                    must => [
                                        {
                                            exists =>
                                                { field => 'pod.analyzed' }
                                        },
                                        { term => { indexed => true } },
                                    ],
                                }
                            },
                        ],
                    }
                },
            ],
        },
    } )->size(999)
        ->source( [qw(name module path documentation distribution)] )->all;
}

=head2 history

Find the history of a given module/documentation.

=cut

sub history {
    my ( $self, $type, $module, @path ) = @_;
    my $search
        = $type eq "module"
        ? $self->query( {
        nested => {
            path  => 'module',
            query => {
                constant_score => {
                    filter => {
                        bool => {
                            must => [
                                { term => { "module.authorized" => true } },
                                { term => { "module.indexed"    => true } },
                                { term => { "module.name" => $module } },
                            ]
                        }
                    }
                }
            }
        }
        } )
        : $type eq "file" ? $self->query( {
        bool => {
            must => [
                { term => { path         => join( "/", @path ) } },
                { term => { distribution => $module } },
            ]
        }
        } )

        # XXX: to fix: no filtering on 'release' so this query
        # will produce modules matching duplications. -- Mickey
        : $type eq "documentation" ? $self->query( {
        bool => {
            must => [
                { match_phrase => { documentation => $module } },
                { term         => { indexed       => true } },
                { term         => { authorized    => true } },
            ]
        }
        } )

        # clearly, one doesn't know what they want in this case
        : $self->query(
        bool => {
            must => [
                { term => { indexed    => true } },
                { term => { authorized => true } },
            ]
        }
        );
    return $search->sort( [ { date => 'desc' } ] );
}

sub _autocomplete {
    my ( $self, $query ) = @_;

    my $search_size = 100;

    my $sugg_res = $self->es->search(
        es_doc_path('file'),
        body => {
            suggest => {
                documentation => {
                    text       => $query,
                    completion => {
                        field => "suggest",
                        size  => $search_size,
                    },
                },
            }
        },
    );

    my %docs;
    for my $suggest ( @{ $sugg_res->{suggest}{documentation}[0]{options} } ) {
        $docs{ $suggest->{text} } = max grep {defined}
            ( $docs{ $suggest->{text} }, $suggest->{score} );
    }

    my $res = $self->es->search(
        es_doc_path('file'),
        body => {
            query => {
                bool => {
                    must => [
                        { term  => { indexed       => true } },
                        { term  => { authorized    => true } },
                        { term  => { status        => 'latest' } },
                        { terms => { documentation => [ keys %docs ] } },
                    ],
                    must_not => [
                        {
                            terms => { distribution => \@ROGUE_DISTRIBUTIONS }
                        },
                    ],
                }
            },
            _source => [ qw(
                author
                date
                deprecated
                distribution
                documentation
                release
            ) ],
            size => $search_size,
        },
    );

    my $hits = $res->{hits}{hits};

    my $fav_res
        = $self->agg_by_distributions(
        [ map $_->{_source}{distribution}, @$hits ] );

    my $favs = $fav_res->{favorites};

    my %valid = map {
        my $source = $_->{_source};
        (
            $source->{documentation} => {
                %$source, favorites => $favs->{ $source->{distribution} },
            }
        );
    } @{ $res->{hits}{hits} };

    # remove any exact match, it will be added later
    my $exact = delete $valid{$query};

    no warnings 'uninitialized';
    my @sorted = map { $valid{$_} }
        sort {
        my $a_data = $valid{$a};
        my $b_data = $valid{$b};
               $a_data->{deprecated} <=> $b_data->{deprecated}
            || $b_data->{favorites}  <=> $a_data->{favorites}
            || $docs{$b}             <=> $docs{$a}
            || length($a)            <=> length($b)
            || $a cmp $b
        }
        keys %valid;

    return {
        took        => $sugg_res->{took} + $res->{took} + $fav_res->{took},
        suggestions => \@sorted,
    };
}

sub autocomplete {
    my ( $self, @terms ) = @_;
    my $data = $self->_autocomplete( join ' ', @terms );

    return {
        took => $data->{took},
        hits => {
            hits => [
                map {
                    my $source = $_;
                    +{
                        fields => {
                            map +( $_ => $source->{$_} ), qw(
                                documentation
                                release
                                author
                                distribution
                            ),
                        },
                    };
                } @{ $data->{suggestions} }
            ],
        },
    };
}

sub autocomplete_suggester {
    my ( $self, @terms ) = @_;
    my $data = $self->_autocomplete( join ' ', @terms );

    return {
        took        => $data->{took},
        suggestions => [
            map +{
                author       => $_->{author},
                date         => $_->{date},
                deprecated   => $_->{deprecated},
                distribution => $_->{distribution},
                name         => $_->{documentation},
                release      => $_->{release},
            },
            @{ $data->{suggestions} }
        ],
    };
}

__PACKAGE__->meta->make_immutable;
1;
