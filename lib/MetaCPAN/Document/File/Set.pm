package MetaCPAN::Document::File::Set;

use Moose;

use List::Util                qw( max );
use MetaCPAN::Query::Favorite ();
use MetaCPAN::Query::File     ();
use MetaCPAN::Query::Release  ();
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar true false );

extends 'ElasticSearchX::Model::Document::Set';

has query_file => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::File',
    lazy    => 1,
    builder => '_build_query_file',
    handles => [ qw(
        dir
        interesting_files
        files_by_category
    ) ],
);

sub _build_query_file {
    my $self = shift;
    return MetaCPAN::Query::File->new(
        es         => $self->es,
        index_name => $self->index->name,
    );
}

has query_favorite => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Favorite',
    lazy    => 1,
    builder => '_build_query_favorite',
    handles => [qw< agg_by_distributions >],
);

sub _build_query_favorite {
    my $self = shift;
    return MetaCPAN::Query::Favorite->new(
        es         => $self->es,
        index_name => $self->index->name,
    );
}

has query_release => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Release',
    lazy    => 1,
    builder => '_build_query_release',
    handles => [qw< find_download_url >],
);

sub _build_query_release {
    my $self = shift;
    return MetaCPAN::Query::Release->new(
        es         => $self->es,
        index_name => $self->index->name,
    );
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
    my @candidates = $self->index->type('file')->query( {
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
    } )->sort( [
        '_score',
        { 'version_numified' => { order => 'desc' } },
        { 'date'             => { order => 'desc' } },
        { 'mime'             => { order => 'asc' } },
        { 'stat.mtime'       => { order => 'desc' } }
    ] )->search_type('dfs_query_then_fetch')->size(100)->all;

    my ($file) = grep {
        grep { $_->indexed && $_->authorized && $_->name eq $module }
            @{ $_->module || [] }
    } grep { !$_->documentation || $_->documentation eq $module }
        @candidates;

    $file ||= shift @candidates;
    return $file ? $self->get( $file->id ) : undef;
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

sub autocomplete {
    my ( $self, @terms ) = @_;
    my $query = join( q{ }, @terms );
    return $self unless $query;

    my $data = $self->search_type('dfs_query_then_fetch')->query( {
        bool => {
            must => [
                {
                    multi_match => {
                        query    => $query,
                        type     => 'most_fields',
                        fields   => [ 'documentation', 'documentation.*' ],
                        analyzer => 'camelcase',
                        minimum_should_match => '80%'
                    }
                },
                { exists => { field      => 'documentation' } },
                { term   => { status     => 'latest' } },
                { term   => { indexed    => true } },
                { term   => { authorized => true } }
            ],
            must_not =>
                [ { terms => { distribution => \@ROGUE_DISTRIBUTIONS } }, ],
        },
    } )->sort( [ '_score', 'documentation' ] );

    $data = $data->fields( [qw(documentation release author distribution)] )
        unless $self->fields;

    $data = $data->source(0)->raw->all;

    single_valued_arrayref_to_scalar( $_->{fields} )
        for @{ $data->{hits}{hits} };

    return $data;
}

sub autocomplete_suggester {
    my ( $self, $query ) = @_;
    return $self unless $query;

    my $search_size = 100;

    my $suggestions
        = $self->search_type('dfs_query_then_fetch')->es->suggest( {
        index => $self->index->name,
        body  => {
            documentation => {
                text       => $query,
                completion => {
                    field => "suggest",
                    size  => $search_size,
                }
            }
        },
        } );

    my %docs;

    for my $suggest ( @{ $suggestions->{documentation}[0]{options} } ) {
        $docs{ $suggest->{text} } = max grep {defined}
            ( $docs{ $suggest->{text} }, $suggest->{score} );
    }

    my @fields = qw(
        author
        date
        deprecated
        distribution
        documentation
        release
    );
    my $data = $self->es->search( {
        index => $self->index->name,
        type  => 'file',
        body  => {
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
        },
        fields => \@fields,
        size   => $search_size,
    } );

    my %valid = map {
        my $got = $_->{fields};
        my %record;
        @record{@fields} = map { $got->{$_}[0] } @fields;
        $record{name} = delete $record{documentation};       # rename
        ( $_->{fields}{documentation}[0] => \%record );
    } @{ $data->{hits}{hits} };

    # remove any exact match, it will be added later
    my $exact = delete $valid{$query};

    my $favorites
        = $self->agg_by_distributions(
        [ map { $_->{distribution} } values %valid ] )->{favorites};

    no warnings 'uninitialized';
    my @sorted = map { $valid{$_} }
        sort {
               $valid{$a}->{deprecated} <=> $valid{$b}->{deprecated}
            || $favorites->{ $valid{$b}->{distribution} }
            <=> $favorites->{ $valid{$a}->{distribution} }
            || $docs{$b}  <=> $docs{$a}
            || length($a) <=> length($b)
            || $a cmp $b
        }
        keys %valid;

    return +{ suggestions => [ grep {defined} ( $exact, @sorted ) ] };
}

sub find_changes_files {
    my ( $self, $author, $release ) = @_;
    my $result = $self->files_by_category( $author, $release, ['changelog'],
        { fields => true } );
    my ($file) = @{ $result->{categories}{changelog} || [] };
    return $file;
}

__PACKAGE__->meta->make_immutable;
1;
