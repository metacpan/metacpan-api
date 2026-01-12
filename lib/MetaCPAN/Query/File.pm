package MetaCPAN::Query::File;

use MetaCPAN::Moose;

use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util     qw( hit_total true false );

with 'MetaCPAN::Query::Role::Common';

sub dir {
    my ( $self, $author, $release, @path ) = @_;

    my $body = {
        query => {
            bool => {
                must => [
                    { term => { 'level'   => scalar @path } },
                    { term => { 'author'  => $author } },
                    { term => { 'release' => $release } },
                    {
                        prefix => {
                            'path' => join( q{/}, @path, q{} )
                        }
                    },
                ]
            },
        },
        size    => 999,
        _source => [
            qw(name stat.mtime path stat.size directory slop documentation mime)
        ],
    };

    my $data = $self->es->search( {
        es_doc_path('file'), body => $body,
    } );

    my $dir = [ map { $_->{_source} } @{ $data->{hits}{hits} } ];

    return { dir => $dir };
}

sub _doc_files {
    my @files = @_;
    my %s;
    return
        map +( "$_", "$_.pod", "$_.md", "$_.markdown", "$_.mdown",
        "$_.mkdn", ),
        grep !$s{$_}++,
        map +( $_, uc $_ ),
        @_;
}

my %special_files = (
    changelog => [
        _doc_files( qw(
            Changelog
            ChangeLog
            Changes
            News
        ) ),
    ],
    contributing => [
        _doc_files( qw(
            Contributing
            Hacking
            Development
        ) ),
    ],
    license => [ qw(
        LICENCE
        LICENSE
        Copyright
        COPYRIGHT
        Copying
        COPYING
        Artistic
        ARTISTIC
    ) ],
    install => [
        _doc_files( qw(
            Install
        ) ),
    ],
    dist => [ qw(
        Build.PL
        MANIFEST
        META.json
        META.yml
        Makefile.PL
        alienfile
        cpanfile
        prereqs.json
        prereqs.yml
        dist.ini
        minil.toml
    ) ],
    security => [
        _doc_files( qw(
            Security
            security
        ) ),
        qw(
            security.txt
        ),
    ],
    other => [
        _doc_files( qw(
            Authors
            Credits
            FAQ
            README
            THANKS
            ToDo
            Todo
        ) ),
    ],
);
my %perl_files = (
    changelog => [ qw(
        perldelta.pod
    ) ],
    license => [ qw(
        perlartistic.pod
        perlgpl.pod
    ) ],
    contributing => [ qw(
        perlhack.pod
    ) ],
);

my @shared_path_prefix_examples = qw(
    example
    examples
    Example
    Examples
    sample
    samples
    demo
    demos
);

my %path_files = (
    example => [
        qw(
            eg
            ex
        ),
        @shared_path_prefix_examples,
    ],
);

my %prefix_files = ( example => [ @shared_path_prefix_examples, ], );

my %file_to_type;
my %type_to_regex;
my %query_parts;

my %sort_order;

for my $type ( keys %special_files ) {
    my @files      = @{ $special_files{$type} || [] };
    my @perl_files = @{ $perl_files{$type}    || [] };

    $sort_order{ $files[$_] } = $_ for 0 .. $#files;

    my @root_file     = grep !/\.pod$/, @files;
    my @non_root_file = grep /\.pod$/,  @files;

    my @parts;
    if (@root_file) {
        push @parts,
            {
            bool => {
                must => [
                    { term  => { level => 0 } },
                    { terms => { name  => \@root_file } },
                ],
                (
                    @perl_files
                    ? ( must_not =>
                            [ { term => { distribution => 'perl' } } ] )
                    : ()
                ),
            }
            };
    }
    if (@non_root_file) {
        push @parts,
            {
            bool => {
                must => [ { terms => { name => \@non_root_file } } ],
                (
                    @perl_files
                    ? ( must_not =>
                            [ { term => { distribution => 'perl' } } ] )
                    : ()
                ),
            }
            };
    }
    if (@perl_files) {
        push @parts,
            {
            bool => {
                must => [
                    { term  => { distribution => 'perl' } },
                    { terms => { name         => \@perl_files } },
                ],
            }
            };
    }

    $file_to_type{$_} = $type for @files, @perl_files;
    push @{ $query_parts{$type} }, @parts;
}

for my $type ( keys %prefix_files ) {
    my @prefixes = @{ $prefix_files{$type} };

    my @parts = map +{ prefix => { 'name' => $_ } }, @prefixes;

    push @{ $query_parts{$type} }, @parts;

    my ($regex) = map qr{(?:\A|/)(?:$_)[^/]*\z}, join '|', @prefixes;

    if ( $type_to_regex{$type} ) {
        $type_to_regex{$type} = qr{$type_to_regex{$type}|$regex};
    }
    else {
        $type_to_regex{$type} = $regex;
    }
}

for my $type ( keys %path_files ) {
    my @prefixes = @{ $path_files{$type} };

    my @parts = map +{ prefix => { 'path' => "$_/" } }, @prefixes;

    push @{ $query_parts{$type} }, @parts;

    my ($regex) = map qr{\A(?:$_)/}, join '|', @prefixes;

    if ( $type_to_regex{$type} ) {
        $type_to_regex{$type} = qr{$type_to_regex{$type}|$regex};
    }
    else {
        $type_to_regex{$type} = $regex;
    }
}

sub interesting_files {
    my ( $self, $author, $release, $categories, $options ) = @_;

    $categories = [ sort keys %query_parts ]
        if !$categories || !@$categories;

    my $return = {
        files => [],
        total => 0,
        took  => 0,
    };

    my @clauses = map @{ $query_parts{$_} // [] }, @$categories;

    return $return
        unless @clauses;

    $options->{_source} //= [ qw(
        author
        distribution
        documentation
        name
        path
        pod_lines
        release
        status
    ) ];
    $options->{size} //= 250;

    my $body = {
        query => {
            bool => {
                must => [
                    { term => { release   => $release } },
                    { term => { author    => $author } },
                    { term => { directory => false } },
                    { bool => { should    => \@clauses } },
                ],
                must_not => [
                    { prefix => { 'path' => 'corpus/' } },
                    { prefix => { 'path' => 'fatlib/' } },
                    { prefix => { 'path' => 'inc/' } },
                    { prefix => { 'path' => 'local/' } },
                    { prefix => { 'path' => 'perl5/' } },
                    { prefix => { 'path' => 'share/' } },
                    { prefix => { 'path' => 't/' } },
                    { prefix => { 'path' => 'xt/' } },
                ],
            },
        },
        %$options,
    };

    my $data = $self->es->search( {
        es_doc_path('file'), body => $body,
    } );

    $return->{took}  = $data->{took};
    $return->{total} = hit_total($data);

    return $return
        unless $return->{total};

    my $files = [ map $_->{_source}, @{ $data->{hits}{hits} } ];

    for my $file (@$files) {
        my $category = $file_to_type{ $file->{name} };
        if ( !$category ) {
            for my $type ( keys %type_to_regex ) {
                if ( $file->{path} =~ $type_to_regex{$type} ) {
                    $category = $type;
                    last;
                }
            }
        }
        $category ||= 'unknown';

        $file->{category} = $category;
    }

    $return->{files} = $files;

    return $return;
}

sub files_by_category {
    my ( $self, $author, $release, $categories, $options ) = @_;
    my $return = $self->interesting_files( $author, $release, $categories,
        $options );
    my $files = delete $return->{files};

    $return->{categories} = { map +( $_ => [] ), @$categories };

    for my $file (@$files) {
        my $category = $file->{category};
        push @{ $return->{categories}{$category} }, $file;
    }

    for my $category (@$categories) {
        my $files = $return->{categories}{$category};
        @$files = map $_->[0],
            sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] }
            map [ $_, $sort_order{ $_->{name} } || 9999, $_->{path} ],
            @$files;
    }
    return $return;
}

sub find_changes_files {
    my ( $self, $author, $release ) = @_;
    my $result = $self->files_by_category( $author, $release, ['changelog'],
        { _source => true } );
    my ($file) = @{ $result->{categories}{changelog} || [] };
    return $file;
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
                        field           => 'suggest',
                        size            => $search_size,
                        skip_duplicates => true,
                    },
                },
            }
        },
    );

    my @docs;
    for my $suggest ( @{ $sugg_res->{suggest}{documentation}[0]{options} } ) {
        push @docs, $suggest->{text};
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
                        { terms => { documentation => \@docs } },
                    ],
                    must_not => [
                        {
                            terms => {
                                distribution => [
                                    $self->query->distribution->rogue_list
                                ]
                            },
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
        = $self->query->favorite->agg_by_distributions(
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
            || length($a)            <=> length($b)
            || $a cmp $b
        }
        keys %valid;

    return {
        took        => $sugg_res->{took} + $res->{took} + $fav_res->{took},
        suggestions => [ ( $exact ? $exact : () ), @sorted ],
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

sub documented_modules {
    my ( $self, $author, $release ) = @_;
    my $query = {
        bool => {
            must => [
                { term   => { author  => $author } },
                { term   => { release => $release } },
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
    };
    my $res = $self->es->search(
        es_doc_path('file'),
        body => {
            query   => $query,
            size    => 999,
            _source => [qw(name module path documentation distribution)],
        },
    );

    return {
        took  => $res->{took},
        files => [ map $_->{_source}, @{ $res->{hits}{hits} } ],
    };
}

sub find_module {
    my ( $self, $module, $fields ) = @_;

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
    return undef
        if !$file;
    return $self->es->get_source(
        es_doc_path('file'),
        id => $file->{_id},
        ( $fields ? ( _source => $fields ) : () ),
    );
}

sub find_pod {
    my ( $self, $name ) = @_;
    my $file = $self->find_module($name);
    return $file
        unless $file;
    my ($module)
        = grep { $_->{indexed} && $_->{authorized} && $_->{name} eq $name }
        @{ $file->{module} || [] };
    if ( $module && ( my $pod = $module->{associated_pod} ) ) {
        my ( $author, $release, @path ) = split( /\//, $pod );
        my $query = {
            bool => {
                must => [
                    { term => { author  => $author } },
                    { term => { release => $release } },
                    { term => { path    => join( '/', @path ) } },
                ],
            },
        };
        my $pod_file = $self->es->search(
            es_doc_path('file'),
            body => {
                query => $query,
            },
        );
        return $pod_file->{hits}{hits}[0]->{_source};
    }
    else {
        return $file;
    }
}

sub history {
    my ( $self, $type, $name, $path, $opts ) = @_;

    $opts ||= {};
    if ( ref $path ) {
        $path = join '/', @$path;
    }

    my $source = $opts->{fields};

    my $query
        = $type eq "module"
        ? {
        nested => {
            path  => 'module',
            query => {
                constant_score => {
                    filter => {
                        bool => {
                            must => [
                                { term => { "module.authorized" => true } },
                                { term => { "module.indexed"    => true } },
                                { term => { "module.name"       => $name } },
                            ]
                        }
                    }
                }
            }
        }
        }
        : $type eq "file" ? {
        bool => {
            must => [
                { term => { path         => $path } },
                { term => { distribution => $name } },
            ]
        }
        }

        # XXX: to fix: no filtering on 'release' so this query
        # will produce modules matching duplications. -- Mickey
        : $type eq "documentation" ? {
        bool => {
            must => [
                { match_phrase => { documentation => $name } },
                { term         => { indexed       => true } },
                { term         => { authorized    => true } },
            ]
        }
        }
        : return undef;

    my $res = $self->es->search(
        es_doc_path('file'),
        body => {
            query => $query,
            size  => 500,
            sort  => [ { date => 'desc' } ],
            ( $source ? ( _source => $source ) : () ),
        },
    );

    return {
        took  => $res->{took},
        total => hit_total($res),
        files => [ map $_->{_source}, @{ $res->{hits}{hits} } ],
    };
}

__PACKAGE__->meta->make_immutable;
1;
