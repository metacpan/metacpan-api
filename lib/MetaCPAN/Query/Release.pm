package MetaCPAN::Query::Release;
use v5.20;

use MetaCPAN::Moose;

use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util
    qw( MAX_RESULT_WINDOW hit_total single_valued_arrayref_to_scalar true false );

with 'MetaCPAN::Query::Role::Common';

sub author_status {
    my ( $self, $id, $file ) = @_;
    return unless $id and $file;

    my $status = $file->{_source}
        || single_valued_arrayref_to_scalar( $file->{fields} );

    if ( $status and $status->{pauseid} ) {
        $status->{release_count}
            = $self->aggregate_status_by_author( $status->{pauseid} );

        my ( $id_2, $id_1 ) = $id =~ /^((\w)\w)/;
        $status->{links} = {
            cpan_directory =>
                "https://www.cpan.org/authors/id/$id_1/$id_2/$id",
            backpan_directory =>
                "https://cpan.metacpan.org/authors/id/$id_1/$id_2/$id",
            cpants => "https://cpants.cpanauthors.org/author/$id",
            cpantesters_reports =>
                "https://www.cpantesters.org/author/$id_1/$id.html",
            cpantesters_matrix =>
                "https://matrix.cpantesters.org/?author=$id",
            metacpan_explorer =>
                "https://explorer.metacpan.org/?url=/author/$id",
            repology => "https://repology.org/maintainer/$id%40cpan",
        };
    }

    return $status;
}

sub aggregate_status_by_author {
    my ( $self, $pauseid ) = @_;
    my $agg = $self->es->search( {
        es_doc_path('release'),
        body => {
            query => {
                term => { author => $pauseid }
            },
            aggregations => {
                count => { terms => { field => 'status' } }
            },
            size => 0,
        }
    } );
    my %ret = ( cpan => 0, latest => 0, backpan => 0 );
    if ($agg) {
        $ret{ $_->{'key'} } = $_->{'doc_count'}
            for @{ $agg->{'aggregations'}{'count'}{'buckets'} };
    }
    $ret{'backpan-only'} = delete $ret{'backpan'};
    return \%ret;
}

sub get_contributors {
    my ( $self, $author_name, $release_name ) = @_;

    my $res = $self->es->search(
        es_doc_path('contributor'),
        body => {
            query => {
                bool => {
                    must => [
                        { term => { release_name   => $release_name } },
                        { term => { release_author => $author_name } },
                    ],
                },
            },
            size    => 999,
            _source => [qw< email name pauseid >],
        }
    );

    my @contribs = map $_->{_source}, @{ $res->{hits}{hits} };

    @contribs = sort { fc $a->{name} cmp fc $b->{name} } @contribs;

    return { contributors => \@contribs };
}

sub get_files {
    my ( $self, $release, $files ) = @_;

    my $query = +{
        query => {
            bool => {
                must => [
                    { term  => { release => $release } },
                    { terms => { name    => $files } }
                ],
            }
        }
    };

    my $ret = $self->es->search(
        es_doc_path('file'),
        body => {
            query   => $query,
            size    => 999,
            _source => [qw< name path >],
        }
    );

    return {} unless @{ $ret->{hits}{hits} };

    return { files => [ map { $_->{_source} } @{ $ret->{hits}{hits} } ] };
}

sub get_checksums {
    my ( $self, $release ) = @_;

    my $query = { term => { name => $release } };

    my $ret = $self->es->search(
        es_doc_path('release'),
        body => {
            query   => $query,
            size    => 1,
            _source => [qw< checksum_md5 checksum_sha256 >],
        }
    );

    return {} unless @{ $ret->{hits}{hits} };
    return $ret->{hits}{hits}[0]{_source};
}

sub _activity_filters {
    my ( $self, $params, $start ) = @_;
    my ( $author, $distribution, $module, $new_dists )
        = @{$params}{qw( author distribution module new_dists )};

    my @filters
        = ( { range => { date => { gte => $start->epoch . '000' } } } );

    push @filters, +{ term => { author => uc($author) } }
        if $author;

    push @filters, +{ term => { distribution => $distribution } }
        if $distribution;

    push @filters, +{ term => { 'dependency.module' => $module } }
        if $module;

    if ( $new_dists and $new_dists eq 'n' ) {
        push @filters,
            (
            +{ term  => { first  => true } },
            +{ terms => { status => [qw( cpan latest )] } },
            );
    }

    return +{ bool => { must => \@filters } };
}

sub activity {
    my ( $self, $params ) = @_;
    my $res = $params->{res} // '1w';

    my $start
        = DateTime->now->truncate( to => 'month' )->subtract( months => 23 );

    my $filters = $self->_activity_filters( $params, $start );

    my $interval_type
        = $self->es->api_version ge '7_0'
        ? 'calendar_interval'
        : 'interval';

    my $body = {
        query        => { match_all => {} },
        aggregations => {
            histo => {
                filter       => $filters,
                aggregations => {
                    entries => {
                        date_histogram => {
                            field          => 'date',
                            $interval_type => $res,
                        },
                    },
                },
            },
        },
        size => 0,
    };

    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my $data = { map { $_->{key} => $_->{doc_count} }
            @{ $ret->{aggregations}{histo}{entries}{buckets} } };

    my $line = [
        map {
            $data->{ $start->clone->add( months => $_ )->epoch . '000' }
                || 0
        } ( 0 .. 23 )
    ];

    return { activity => $line };
}

sub by_author_and_name {
    my ( $self, $author, $release ) = @_;

    my $body = {
        query => {
            bool => {
                must => [
                    { term => { 'name' => $release } },
                    { term => { author => uc($author) } }
                ]
            }
        }
    };

    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my $data = $ret->{hits}{hits}[0]{_source};

    return {
        took    => $ret->{took},
        release => $data,
        total   => hit_total($ret),
    };
}

sub by_author_and_names {
    my ( $self, $releases ) = @_;

    # $releases: ArrayRef[ Dict[ author => Str, name => Str ] ]

    my $body = {
        size  => ( 0 + @$releases ),
        query => {
            bool => {
                should => [
                    map {
                        +{
                            bool => {
                                must => [
                                    {
                                        term => {
                                            author => uc( $_->{author} )
                                        }
                                    },
                                    { term => { 'name' => $_->{name} } },
                                ]
                            }
                        }
                    } @$releases
                ]
            }
        }
    };

    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my @releases;
    for my $hit ( @{ $ret->{hits}{hits} } ) {
        my $src = $hit->{_source};
        push @releases, $src;
    }

    return {
        took     => $ret->{took},
        total    => hit_total($ret),
        releases => \@releases,
    };
}

sub by_author {
    my ( $self, $pauseid, $page, $size ) = @_;
    $size //= 1000;
    $page //= 1;

    if ( $page * $size >= MAX_RESULT_WINDOW ) {
        return {
            releases => [],
            took     => 0,
            total    => 0,
        };
    }

    my $body = {
        query => {
            bool => {
                must => [
                    { terms => { status => [qw< cpan latest >] } },
                    ( $pauseid ? { term => { author => $pauseid } } : () ),
                ],
            }
        },
        sort    => [ 'distribution', { 'version_numified' => 'desc' } ],
        _source => [
            qw( abstract author authorized date distribution license metadata.version resources.repository status tests )
        ],
        size => $size,
        from => ( $page - 1 ) * $size,
    };

    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my $data = [ map { $_->{_source} } @{ $ret->{hits}{hits} } ];

    return {
        releases => $data,
        total    => hit_total($ret),
        took     => $ret->{took}
    };
}

sub latest_by_distribution {
    my ( $self, $distribution ) = @_;

    my $body = {
        query => {
            bool => {
                must => [
                    {
                        term => {
                            'distribution' => $distribution
                        }
                    },
                    { term => { status => 'latest' } }
                ]
            }
        },
        sort => [ { date => 'desc' } ],
        size => 1
    };

    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my $data = $ret->{hits}{hits}[0]{_source};

    return {
        release => $data,
        took    => $ret->{took},
        total   => hit_total($ret),
    };
}

sub latest_by_author {
    my ( $self, $pauseid ) = @_;

    my $body = {
        query => {
            bool => {
                must => [
                    { term => { author => uc($pauseid) } },
                    { term => { status => 'latest' } }
                ]
            }
        },
        sort    => [ 'distribution', { 'version_numified' => 'desc' } ],
        _source => [
            qw(author distribution name status abstract date download_url version authorized maturity)
        ],
        size => 1000,
    };

    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my $data = [ map { $_->{_source} } @{ $ret->{hits}{hits} } ];

    return { took => $ret->{took}, releases => $data };
}

sub all_by_author {
    my ( $self, $author, $page, $size ) = @_;
    $size //= 100;
    $page //= 1;

    if ( $page * $size >= MAX_RESULT_WINDOW ) {
        return {
            releases => [],
            took     => 0,
            total    => 0,
        };
    }

    my $body = {
        query   => { term => { author => uc($author) } },
        sort    => [ { date => 'desc' } ],
        _source => [
            qw(author distribution name status abstract date download_url version authorized maturity)
        ],
        size => $size,
        from => ( $page - 1 ) * $size,
    };
    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my $data = [ map { $_->{_source} } @{ $ret->{hits}{hits} } ];

    return {
        took     => $ret->{took},
        releases => $data,
        total    => hit_total($ret),
    };
}

sub versions {
    my ( $self, $dist, $versions ) = @_;

    my $size = 1000;

    my $query;

    # 'versions' param was sent
    if ( @{$versions} ) {
        my $filter_versions;

        # we only want 'latest' version
        if ( @{$versions} == 1 and $versions->[0] eq 'latest' ) {
            $filter_versions = { term => { status => 'latest' } };
        }
        else {
            if ( grep $_ eq 'latest', @{$versions} ) {

                # we want a combination of 'latest' and specific versions
                @{$versions} = grep $_ ne 'latest', @{$versions};
                $filter_versions = {
                    bool => {
                        should => [
                            { terms => { version => $versions } },
                            { term  => { status  => 'latest' } },
                        ],
                    }
                };
            }
            else {
                # we only want specific versions
                $filter_versions = { terms => { version => $versions } };
            }
        }

        $query = {
            bool => {
                must => [
                    { term => { distribution => $dist } },
                    $filter_versions
                ]
            }
        };
    }
    else {
        $query = { term => { distribution => $dist } };
    }

    my $body = {
        query   => $query,
        size    => $size,
        sort    => [ { date => 'desc' } ],
        _source => [ qw(
            name
            date
            author
            version
            status
            maturity
            authorized
            download_url
            main_module
        ) ],
    };

    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my $data = [ map { $_->{_source} } @{ $ret->{hits}{hits} } ];

    return {
        releases => $data,
        total    => hit_total($ret),
        took     => $ret->{took}
    };
}

sub top_uploaders {
    my ( $self, $range ) = @_;
    my $range_filter = {
        range => {
            date => {
                gte => $range eq 'all' ? 0 : DateTime->now->subtract(
                      $range eq 'weekly'  ? 'weeks'
                    : $range eq 'monthly' ? 'months'
                    : $range eq 'yearly'  ? 'years'
                    :                       'weeks' => 1
                )->truncate( to => 'day' )->iso8601
            },
        }
    };

    my $body = {
        query        => { match_all => {} },
        aggregations => {
            author => {
                aggregations => {
                    entries => {
                        terms => { field => 'author', size => 50 }
                    }
                },
                filter => $range_filter,
            },
        },
        size => 0,
    };

    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my $counts = { map { $_->{key} => $_->{doc_count} }
            @{ $ret->{aggregations}{author}{entries}{buckets} } };

    return {
        counts => $counts,
        took   => $ret->{took}
    };
}

sub requires {
    my ( $self, $module, $page, $page_size, $sort ) = @_;
    return $self->_get_depended_releases( [$module], $page, $page_size,
        $sort );
}

sub reverse_dependencies {
    my ( $self, $distribution, $page, $page_size, $sort ) = @_;

    # get the latest release of given distribution
    my $release = $self->_get_latest_release($distribution) || return;

    # get (authorized/indexed) modules provided by the release
    my $modules = $self->_get_provided_modules($release) || return;

    # return releases depended on those modules
    return $self->_get_depended_releases( $modules, $page, $page_size,
        $sort );
}

sub _get_latest_release {
    my ( $self, $distribution ) = @_;

    my $release = $self->es->search(
        es_doc_path('release'),
        body => {
            query => {
                bool => {
                    must => [
                        { term => { distribution => $distribution } },
                        { term => { status       => 'latest' } },
                        { term => { authorized   => true } },
                    ]
                },
            },
            _source => [qw< name author >],
        },
    );

    my ($release_info) = map { $_->{_source} } @{ $release->{hits}{hits} };

    return $release_info->{name} && $release_info->{author}
        ? +{
        name   => $release_info->{name},
        author => $release_info->{author},
        }
        : undef;
}

sub _get_provided_modules {
    my ( $self, $release ) = @_;

    my $provided_modules = $self->es->search(
        es_doc_path('file'),
        body => {
            query => {
                bool => {
                    must => [
                        { term => { 'release' => $release->{name} } },
                        { term => { 'author'  => $release->{author} } },
                        { term => { 'module.authorized' => true } },
                        { term => { 'module.indexed'    => true } },
                    ]
                }
            },
            size => 999,
        }
    );

    my @modules = map { $_->{name} }
        grep { $_->{indexed} && $_->{authorized} }
        map  { @{ $_->{_source}{module} } }
        @{ $provided_modules->{hits}{hits} };

    return @modules ? \@modules : undef;
}

sub _fix_sort_value {
    my $sort = shift;

    if ( $sort && $sort =~ /^(\w+):(asc|desc)$/ ) {
        return { $1 => $2 };
    }
    else {
        return { date => 'desc' };
    }
}

sub _get_depended_releases {
    my ( $self, $modules, $page, $page_size, $sort ) = @_;
    $page      //= 1;
    $page_size //= 50;

    if ( $page * $page_size >= MAX_RESULT_WINDOW ) {
        return +{
            data  => [],
            took  => 0,
            total => 0,
        };
    }

    $sort = _fix_sort_value($sort);

    my $dependency_filter = {
        nested => {
            path  => 'dependency',
            query => {
                bool => {
                    must => [
                        {
                            term =>
                                { 'dependency.relationship' => 'requires' }
                        },
                        {
                            terms => {
                                'dependency.phase' => [ qw(
                                    configure
                                    build
                                    runtime
                                    test
                                ) ]
                            }
                        },
                        { terms => { 'dependency.module' => $modules } },
                    ],
                },
            },
        },
    };

    my $depended = $self->es->search(
        es_doc_path('release'),
        body => {
            query => {
                bool => {
                    must => [
                        $dependency_filter,
                        { term => { status     => 'latest' } },
                        { term => { authorized => true } },
                    ],
                },
            },
            size => $page_size,
            from => ( $page - 1 ) * $page_size,
            sort => $sort,
        }
    );

    return +{
        data  => [ map { $_->{_source} } @{ $depended->{hits}{hits} } ],
        total => hit_total($depended),
        took  => $depended->{took},
    };
}

sub recent {
    my ( $self, $type, $page, $page_size ) = @_;
    $page      //= 1;
    $page_size //= 10000;
    $type      //= '';

    if ( $page * $page_size >= MAX_RESULT_WINDOW ) {
        return +{
            releases => [],
            took     => 0,
            total    => 0,
        };
    }

    my $query;
    if ( $type eq 'n' ) {
        $query = {
            bool => {
                must => [
                    { term  => { first  => true } },
                    { terms => { status => [qw< cpan latest >] } },
                ]
            }
        };
    }
    elsif ( $type eq 'a' ) {
        $query = { match_all => {} };
    }
    else {
        $query = { terms => { status => [qw< cpan latest >] } };
    }

    my $body = {
        size    => $page_size,
        from    => ( $page - 1 ) * $page_size,
        query   => $query,
        _source =>
            [qw(name author status abstract date distribution maturity)],
        sort => [ { 'date' => { order => 'desc' } } ]
    };

    my $ret = $self->es->search( es_doc_path('release'), body => $body, );

    my $data = [ map { $_->{_source} } @{ $ret->{hits}{hits} } ];

    return {
        releases => $data,
        total    => hit_total($ret),
        took     => $ret->{took}
    };
}

sub modules {
    my ( $self, $author, $release ) = @_;

    my $body = {
        query => {
            bool => {
                must => [
                    { term => { release   => $release } },
                    { term => { author    => $author } },
                    { term => { directory => false } },
                    {
                        bool => {
                            should => [
                                {
                                    bool => {
                                        must => [
                                            {
                                                exists => {
                                                    field => 'module.name'
                                                }
                                            },
                                            {
                                                term => {
                                                    'module.indexed' => true
                                                }
                                            }
                                        ]
                                    }
                                },
                                {
                                    bool => {
                                        must => [
                                            {
                                                range => {
                                                    slop => { gt => 0 }
                                                }
                                            },
                                            {
                                                exists => {
                                                    field => 'pod.analyzed'
                                                }
                                            },
                                            {
                                                term => { 'indexed' => true }
                                            },
                                        ]
                                    }
                                }
                            ]
                        }
                    }
                ]
            }
        },
        size => 999,

        # Sort by documentation name; if there isn't one, sort by path.
        sort => [ 'documentation', 'path' ],

        _source => [ qw(
            module
            abstract
            author
            authorized
            distribution
            documentation
            indexed
            path
            pod_lines
            release
            status
        ) ],
    };

    my $ret = $self->es->search( es_doc_path('file'), body => $body, );

    my @files = map $_->{_source}, @{ $ret->{hits}{hits} };

    return {
        files => \@files,
        total => hit_total($ret),
        took  => $ret->{took}
    };
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

    $release->find_download_url( 'module', 'Foo', { version => $version, dev => 0|1 });

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
    my ( $self, $type, $name, $args ) = @_;
    $args ||= {};

    my $dev              = $args->{dev};
    my $version          = $args->{version};
    my $explicit_version = $version && $version =~ /==/;

    my @filters;

    die 'type must be module or dist'
        unless $type eq 'module' || $type eq 'dist';
    my $module_filter = $type eq 'module';

    if ( !$explicit_version ) {
        push @filters,
            { bool => { must_not => [ { term => { status => 'backpan' } } ] }
            };
        if ( !$dev ) {
            push @filters, { term => { maturity => 'released' } };
        }
    }

    my $prefix = $module_filter ? 'module.' : '';

    my $version_filters
        = $self->_version_filters( $version, $prefix . 'version_numified' );

    my $entity_filter = {
        bool => {
            must => [
                { term => { $prefix . 'authorized' => true } },
                (
                    $module_filter
                    ? (
                        { term => { $prefix . 'indexed' => true } },
                        { term => { $prefix . 'name'    => $name } }
                        )
                    : { term => { 'distribution' => $name } },
                ),
                (
                    exists $version_filters->{must}
                    ? @{ $version_filters->{must} }
                    : ()
                )
            ],
            (
                exists $version_filters->{must_not}
                ? ( must_not => [ @{ $version_filters->{must_not} } ] )
                : ()
            )
        }
    };

    # filters to be applied to the nested modules
    if ($module_filter) {
        push @filters,
            {
            nested => {
                path  => 'module',
                query => $entity_filter,
            }
            };
    }
    else {
        push @filters, $entity_filter;
    }

    my $filter
        = @filters
        ? { bool => { must => \@filters } }
        : $filters[0];

    my $version_sort
        = $module_filter
        ? {
        'module.version_numified' => {
            mode  => 'max',
            order => 'desc',
            (
                $self->es->api_version ge '6_0'
                ? (
                    nested => {
                        path   => 'module',
                        filter => $entity_filter,
                    },
                    )
                : (
                    nested_path   => 'module',
                    nested_filter => $entity_filter,
                )
            ),
        }
        }
        : { version_numified => { order => 'desc' } };

    # sort by score, then version desc, then date desc
    my @sort = ( '_score', $version_sort, { date => { order => 'desc' } } );

    my $query;

    if ($dev) {
        $query = $filter;
    }
    else {
        # if not dev, then prefer latest > cpan > backpan
        $query = {
            function_score => {
                query      => $filter,
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

    my $body = {
        query   => $query,
        size    => 1,
        sort    => \@sort,
        _source => [ qw(
            checksum_md5
            checksum_sha256
            date
            distribution
            download_url
            release
            status
            version
            name
        ) ],
    };

    my $res = $self->es->search(
        es_doc_path( $module_filter ? 'file' : 'release' ),
        body        => $body,
        search_type => 'dfs_query_then_fetch',
    );

    return unless hit_total($res);

    my @checksums;

    my $hit     = $res->{hits}{hits}[0];
    my $source  = $hit->{_source};
    my $release = $source->{release};

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

    my $source_name = delete $source->{name};
    if ( !$module_filter ) {
        $source->{release} = $source_name;
    }

    my $module
        = $hit->{inner_hits}{module}
        ? $hit->{inner_hits}{module}{hits}{hits}[0]{_source}
        : {};

    return +{ %$source, %$module, @checksums, };
}

sub _version_filters {
    my ( $self, $version, $field ) = @_;

    return () unless $version;

    if ( $version =~ s/^==\s*// ) {
        return +{
            must => [ {
                term => {
                    $field => $self->_numify($version)
                }
            } ]
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
                = [ { range => { $field => \%range } } ];
        }

        if (@exclusion) {
            $filters{must_not} = [];
            push @{ $filters{must_not} },
                map { +{ term => { $field => $self->_numify($_) } } }
                @exclusion;
        }

        return \%filters;
    }
    elsif ( $version !~ /\s/ ) {
        return +{
            must => [ {
                range => {
                    $field => { 'gte' => $self->_numify($version) }
                },
            } ]
        };
    }
}

sub _numify {
    my ( $self, $ver ) = @_;
    $ver =~ s/_//g;
    version->new($ver)->numify;
}

sub predecessor {
    my ( $self, $name ) = @_;

    my $res = $self->es->search(
        es_doc_path('release'),
        body => {
            query => {
                bool => {
                    must     => [ { term => { distribution => $name } }, ],
                    must_not => [ { term => { status       => 'latest' } }, ],
                },
            },
            sort => [ { date => 'desc' } ],
            size => 1,
        },
    );
    my ($release) = $res->{hits}{hits}[0];
    return unless $release;
    return $release->{_source};
}

sub find {
    my ( $self, $name ) = @_;

    my $res = $self->es->search(
        es_doc_path('release'),
        body => {
            query => {
                bool => {
                    must => [
                        { term => { distribution => $name } },
                        { term => { status       => 'latest' } },
                    ],
                },
            },
            sort => [ { date => 'desc' } ],
            size => 1,
        },
    );
    my ($file) = $res->{hits}{hits}[0];
    return undef unless $file;
    return $file->{_source};
}

__PACKAGE__->meta->make_immutable;
1;
