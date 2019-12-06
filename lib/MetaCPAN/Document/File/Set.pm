package MetaCPAN::Document::File::Set;

use Moose;

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );
use Ref::Util qw( is_hashref );
use List::Util qw( max );

use MetaCPAN::Query::File;
use MetaCPAN::Query::Favorite;
use MetaCPAN::Query::Release;

extends 'ElasticSearchX::Model::Document::Set';

has query_file => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::File',
    lazy    => 1,
    builder => '_build_query_file',
    handles => [qw< dir interesting_files >],
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
    handles => [qw< get_checksums >],
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
    my @candidates = $self->index->type('file')->query(
        {
            bool => {
                must => [
                    { term => { indexed    => 1, } },
                    { term => { authorized => 1 } },
                    { term => { status     => 'latest' } },
                    {
                        or => [
                            {
                                nested => {
                                    path   => "module",
                                    filter => {
                                        and => [
                                            {
                                                term => {
                                                    "module.name" => $module
                                                }
                                            },
                                            {
                                                term => {
                                                    "module.authorized" => 1
                                                }
                                            },
                                        ]
                                    }
                                }
                            },
                            { term => { documentation => $module } },
                        ]
                    },
                ],
                should => [
                    { term => { documentation => $module } },
                    {
                        nested => {
                            path   => 'module',
                            filter => {
                                and => [
                                    { term => { 'module.name' => $module } },
                                    {
                                        exists => {
                                            field => 'module.associated_pod'
                                        }
                                    },
                                ]
                            }
                        }
                    },
                ]
            }
        }
    )->sort(
        [
            '_score',
            { 'version_numified' => { order => 'desc' } },
            { 'date'             => { order => 'desc' } },
            { 'mime'             => { order => 'asc' } },
            { 'stat.mtime'       => { order => 'desc' } }
        ]
    )->search_type('dfs_query_then_fetch')->size(100)->all;

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
        return $self->get(
            {
                author  => $author,
                release => $release,
                path    => join( '/', @path ),
            }
        );
    }
    else {
        return $file;
    }
}

sub documented_modules {
    my ( $self, $release ) = @_;
    return $self->filter(
        {
            and => [
                { term => { release => $release->{name} } },
                { term => { author  => $release->{author} } },
                {
                    or => [
                        {
                            and => [
                                {
                                    exists => {
                                        field => 'module.name',
                                    }
                                },
                                {
                                    term => {
                                        'module.indexed' => 1
                                    }
                                },
                            ]
                        },
                        {
                            and => [
                                {
                                    exists => {
                                        field => 'pod.analyzed',
                                    }
                                },
                                { term => { indexed => 1 } },
                            ]
                        },
                    ]
                },
            ],
        }
    )->size(999)
        ->source( [qw(name module path documentation distribution)] )->all;
}

=head2 find_download_url


cpanm Foo
=> status: latest, maturity: released

cpanm --dev Foo
=> status: -backpan, sort_by: version_numified,date

cpanm Foo~1.0
=> status: latest, maturity: released, module.version_numified: gte: 1.0

cpanm --dev Foo~1.0
-> status: -backpan, module.version_numified: gte: 1.0, sort_by: version_numified,date

cpanm Foo~<2
=> maturity: released, module.version_numified: lt: 2, sort_by: status,version_numified,date

cpanm --dev Foo~<2
=> status: -backpan, module.version_numified: lt: 2, sort_by: status,version_numified,date

    $file->find_download_url( 'Foo', { version => $version, dev => 0|1 });

Sorting:

    if it's stable:
      prefer latest > cpan > backpan
      then sort by version desc
      then sort by date descending (rev chron)

    if it's dev:
      sort by version desc
      sort by date descending (reverse chronologically)


=cut

sub find_download_url {
    my ( $self, $module, $args ) = @_;
    $args ||= {};

    my $dev              = $args->{dev};
    my $version          = $args->{version};
    my $explicit_version = $version && $version =~ /==/;

    # exclude backpan if dev, and
    # require released modules if neither dev nor explicit version
    my @filters
        = $dev ? { not => { term => { status => 'backpan' } } }
        : !$explicit_version ? { term => { maturity => 'released' } }
        :                      ();

    my $version_filters = $self->_version_filters($version);

    # filters to be applied to the nested modules
    my $module_f = {
        nested => {
            path       => 'module',
            inner_hits => { _source => 'version' },
            filter     => {
                bool => {
                    must => [
                        { term => { 'module.authorized' => 1 } },
                        { term => { 'module.indexed'    => 1 } },
                        { term => { 'module.name'       => $module } },
                        (
                            exists $version_filters->{must}
                            ? @{ $version_filters->{must} }
                            : ()
                        )
                    ],
                    (
                        exists $version_filters->{must_not}
                        ? ( must_not => [ $version_filters->{must_not} ] )
                        : ()
                    )
                }
            }
        }
    };

    my $filter
        = @filters
        ? { bool => { must => [ @filters, $module_f ] } }
        : $module_f;

    # sort by score, then version desc, then date desc
    my @sort = (
        '_score',
        {
            'module.version_numified' => {
                mode          => 'max',
                order         => 'desc',
                nested_path   => 'module',
                nested_filter => $module_f->{nested}{filter}
            }
        },
        { date => { order => 'desc' } }
    );

    my $query;

    if ($dev) {
        $query = { filtered => { filter => $filter } };
    }
    else {
        # if not dev, then prefer latest > cpan > backpan
        $query = {
            function_score => {
                filter     => $filter,
                score_mode => 'first',
                boost_mode => 'replace',
                functions  => [
                    {
                        filter => { term => { status => 'latest' } },
                        weight => 3
                    },
                    {
                        filter => { term => { status => 'cpan' } },
                        weight => 2
                    },
                    { filter => { match_all => {} }, weight => 1 },
                ]
            }
        };
    }

    my $res
        = $self->size(1)->query($query)
        ->source( [ 'release', 'download_url', 'date', 'status' ] )
        ->search_type('dfs_query_then_fetch')->sort( \@sort )->raw->all;
    return unless $res->{hits}{total};

    my @checksums;

    my $hit     = $res->{hits}{hits}[0];
    my $release = exists $hit->{_source} ? $hit->{_source}{release} : undef;

    if ($release) {
        my $checksums = $self->get_checksums($release);
        @checksums = (
            (
                $checksums->{checksum_md5}
                ? ( checksum_md5 => $checksums->{checksum_md5} )
                : ()
            ),
            (
                $checksums->{checksum_sha256}
                ? ( checksum_sha256 => $checksums->{checksum_sha256} )
                : ()
            ),
        );
    }

    return +{
        %{ $hit->{_source} },
        %{ $hit->{inner_hits}{module}{hits}{hits}[0]{_source} }, @checksums,
    };
}

sub _version_filters {
    my ( $self, $version ) = @_;

    return () unless $version;

    if ( $version =~ s/^==\s*// ) {
        return +{
            must => [
                {
                    term => {
                        'module.version_numified' => $self->_numify($version)
                    }
                }
            ]
        };
    }
    elsif ( $version =~ /^[<>!]=?\s*/ ) {
        my %ops = qw(< lt <= lte > gt >= gte);
        my ( %filters, %range, @exclusion );
        my @requirements = split /,\s*/, $version;
        for my $r (@requirements) {
            if ( $r =~ s/^([<>]=?)\s*// ) {
                $range{ $ops{$1} } = $self->_numify($r);
            }
            elsif ( $r =~ s/\!=\s*// ) {
                push @exclusion, $self->_numify($r);
            }
        }

        if ( keys %range ) {
            $filters{must}
                = [ { range => { 'module.version_numified' => \%range } } ];
        }

        if (@exclusion) {
            $filters{must_not} = [];
            push @{ $filters{must_not} }, map {
                +{
                    term => {
                        'module.version_numified' => $self->_numify($_)
                    }
                }
            } @exclusion;
        }

        return \%filters;
    }
    elsif ( $version !~ /\s/ ) {
        return +{
            must => [
                {
                    range => {
                        'module.version_numified' =>
                            { 'gte' => $self->_numify($version) }
                    },
                }
            ]
        };
    }
}

sub _numify {
    my ( $self, $ver ) = @_;
    $ver =~ s/_//g;
    version->new($ver)->numify;
}

=head2 history

Find the history of a given module/documentation.

=cut

sub history {
    my ( $self, $type, $module, @path ) = @_;
    my $search
        = $type eq "module"
        ? $self->query(
        {
            nested => {
                path  => 'module',
                query => {
                    constant_score => {
                        filter => {
                            bool => {
                                must => [
                                    { term => { "module.authorized" => 1 } },
                                    { term => { "module.indexed"    => 1 } },
                                    { term => { "module.name" => $module } },
                                ]
                            }
                        }
                    }
                }
            }
        }
        )
        : $type eq "file" ? $self->query(
        {
            bool => {
                must => [
                    { term => { path         => join( "/", @path ) } },
                    { term => { distribution => $module } },
                ]
            }
        }
        )

        # XXX: to fix: no filtering on 'release' so this query
        # will produce modules matching duplications. -- Mickey
        : $type eq "documentation" ? $self->query(
        {
            bool => {
                must => [
                    { match_phrase => { documentation => $module } },
                    { term         => { indexed       => 1 } },
                    { term         => { authorized    => 1 } },
                ]
            }
        }
        )

        # clearly, one doesn't know what they want in this case
        : $self->query(
        bool => {
            must => [
                { term => { indexed    => 1 } },
                { term => { authorized => 1 } },
            ]
        }
        );
    return $search->sort( [ { date => 'desc' } ] );
}

sub autocomplete {
    my ( $self, @terms ) = @_;
    my $query = join( q{ }, @terms );
    return $self unless $query;

    my $data = $self->search_type('dfs_query_then_fetch')->query(
        {
            filtered => {
                query => {
                    multi_match => {
                        query    => $query,
                        type     => 'most_fields',
                        fields   => [ 'documentation', 'documentation.*' ],
                        analyzer => 'camelcase',
                        minimum_should_match => '80%'
                    },
                },
                filter => {
                    bool => {
                        must => [
                            { exists => { field      => 'documentation' } },
                            { term   => { status     => 'latest' } },
                            { term   => { indexed    => 1 } },
                            { term   => { authorized => 1 } }
                        ],
                        must_not => [
                            {
                                terms =>
                                    { distribution => \@ROGUE_DISTRIBUTIONS }
                            },
                        ],
                    }
                }
            }
        }
    )->sort( [ '_score', 'documentation' ] );

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
        = $self->search_type('dfs_query_then_fetch')->es->suggest(
        {
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
        }
        );

    my %docs;

    for my $suggest ( @{ $suggestions->{documentation}[0]{options} } ) {
        $docs{ $suggest->{text} } = max grep {defined}
            ( $docs{ $suggest->{text} }, $suggest->{score} );
    }

    my @fields = (qw(documentation distribution author release deprecated));
    my $data   = $self->es->search(
        {
            index => $self->index->name,
            type  => 'file',
            body  => {
                query => {
                    bool => {
                        must => [
                            { term => { indexed    => 1 } },
                            { term => { authorized => 1 } },
                            { term => { status     => 'latest' } },
                            {
                                terms => { 'documentation' => [ keys %docs ] }
                            },
                        ],
                        must_not => [
                            {
                                terms =>
                                    { distribution => \@ROGUE_DISTRIBUTIONS }
                            },
                        ],
                    }
                },
            },
            fields => \@fields,
            size   => $search_size,
        }
    );

    my %valid = map {
        my $got = $_->{fields};
        my %record;
        @record{@fields} = map { $got->{$_}[0] } @fields;
        $record{name} = delete $record{documentation};    # rename
        ( $_->{fields}{documentation}[0] => \%record );
    } @{ $data->{hits}{hits} };

    # normalize 'deprecated' field values to boolean (1/0) values (because ES)
    for my $v ( values %valid ) {
        $v->{deprecated} = 1 if $v->{deprecated} eq 'true';
        $v->{deprecated} = 0 if $v->{deprecated} eq 'false';
    }

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
            || $docs{$b} <=> $docs{$a}
            || length($a) <=> length($b)
            || $a cmp $b
        }
        keys %valid;

    return +{ suggestions => [ grep {defined} ( $exact, @sorted ) ] };
}

sub find_changes_files {
    my ( $self, $author, $release ) = @_;

    # find the most likely file
    # TODO: should we do this when the release is indexed
    # and store the result as { 'changes_file' => $name }

    my @candidates = qw(
        CHANGELOG
        ChangeLog
        Changelog
        ChangeLog.pm
        changelog.pm
        ChangeLog.pod
        CHANGES
        Changes
        CHANGES.md
        CHANGES.markdown
        CHANGES.pm
        Changes.pm
        CHANGES.pod
        Changes.pod
        NEWS
    );

    # use $c->model b/c we can't let any filters apply here
    my $file = $self->raw->filter(
        {
            and => [
                { term => { release => $release } },
                { term => { author  => $author } },
                {
                    or => [

                        # if it's a perl release, get perldelta
                        {
                            and => [
                                { term => { distribution => 'perl' } },
                                {
                                    term => {
                                        'name' => 'perldelta.pod'
                                    }
                                },
                            ]
                        },

                      # otherwise look for one of these candidates in the root
                        {
                            and => [
                                { term => { level     => 0 } },
                                { term => { directory => 0 } },
                                {
                                    or => [
                                        map { { term => { 'name' => $_ } } }
                                            @candidates
                                    ]
                                }
                            ]
                        }
                    ],
                }
            ]
        }
    )->size(1)

        # HACK: Sort by level/desc to put pod/perldeta.pod first (if found)
        # otherwise sort root files by name and select the first.
        ->sort( [ { level => 'desc' }, { name => 'asc' } ] )->first;

    return unless is_hashref($file);
    return $file->{_source};
}

__PACKAGE__->meta->make_immutable;
1;
