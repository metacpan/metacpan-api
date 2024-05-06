package MetaCPAN::Query::Release;

use MetaCPAN::Moose;

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

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
            cpan_directory    => "http://cpan.org/authors/id/$id_1/$id_2/$id",
            backpan_directory =>
                "https://cpan.metacpan.org/authors/id/$id_1/$id_2/$id",
            cpants              => "http://cpants.cpanauthors.org/author/$id",
            cpantesters_reports =>
                "http://cpantesters.org/author/$id_1/$id.html",
            cpantesters_matrix => "http://matrix.cpantesters.org/?author=$id",
            metacpan_explorer  =>
                "https://explorer.metacpan.org/?url=/author/$id",
            repology => "https://repology.org/maintainer/$id%40cpan",
        };
    }

    return $status;
}

sub aggregate_status_by_author {
    my ( $self, $pauseid ) = @_;
    my $agg = $self->es->search( {
        index => $self->index_name,
        type  => 'release',
        body  => {
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

    my $query = +{
        query => {
            bool => {
                must => [
                    { term => { name   => $release_name } },
                    { term => { author => $author_name } },
                ],
            },
        }
    };

    my $res = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => {
            query   => $query,
            size    => 999,
            _source => [qw< metadata.author metadata.x_contributors >],
        }
    );

    my $release  = $res->{hits}{hits}[0]{_source};
    my $contribs = $release->{metadata}{x_contributors} || [];
    my $authors  = $release->{metadata}{author}         || [];

    for ( \( $contribs, $authors ) ) {

        # If a sole contributor is a string upgrade it to an array...
        $$_ = [$$_]
            if !ref $$_;

        # but if it's any other kind of value don't die trying to parse it.
        $$_ = []
            unless Ref::Util::is_arrayref($$_);
    }
    $authors = [ grep { $_ ne 'unknown' } @$authors ];

    # this check is against a failure in tests (because fake author)
    return
        unless $self->es->exists(
        index => $self->index_name,
        type  => 'author',
        id    => $author_name,
        );

    my $author = $self->es->get(
        index => $self->index_name,
        type  => 'author',
        id    => $author_name,
    );

    my $author_email        = $author->{_source}{email};
    my $author_gravatar_url = $author->{_source}{gravatar_url};

    my $author_info = {
        email => [
            lc "$author_name\@cpan.org",
            (
                Ref::Util::is_arrayref($author_email) ? @{$author_email}
                : $author_email
            ),
        ],
        name => $author_name,
        (
            $author_gravatar_url ? ( gravatar_url => $author_gravatar_url )
            : ()
        ),
    };
    my %seen = map { $_ => $author_info }
        ( @{ $author_info->{email} }, $author_info->{name}, );

    my @contribs = map {
        my $name = $_;
        my $email;
        if ( $name =~ s/\s*<([^<>]+@[^<>]+)>// ) {
            $email = $1;
        }
        my $info;
        my $dupe;
        if ( $email and $info = $seen{$email} ) {
            $dupe = 1;
        }
        elsif ( $info = $seen{$name} ) {
            $dupe = 1;
        }
        else {
            $info = {
                name  => $name,
                email => [],
            };
        }
        $seen{$name} ||= $info;
        if ($email) {
            push @{ $info->{email} }, $email
                unless grep { $_ eq $email } @{ $info->{email} };
            $seen{$email} ||= $info;
        }
        $dupe ? () : $info;
    } ( @$authors, @$contribs );

    for my $contrib (@contribs) {

        # heuristic to autofill pause accounts
        if ( !$contrib->{pauseid} ) {
            my ($pauseid)
                = map { /^(.*)\@cpan\.org$/ ? $1 : () }
                @{ $contrib->{email} };
            $contrib->{pauseid} = uc $pauseid
                if $pauseid;

        }

        # check if contributor's email points to a registered author
        if ( !$contrib->{pauseid} ) {
            for my $email ( @{ $contrib->{email} } ) {
                my $check_author = $self->es->search(
                    index => $self->index_name,
                    type  => 'author',
                    body  => {
                        query => { term => { email => $email } },
                        size  => 10,
                    }
                );

                if ( $check_author->{hits}{total} ) {
                    $contrib->{pauseid}
                        = uc $check_author->{hits}{hits}[0]{_source}{pauseid};
                }
            }
        }
    }

    my $contrib_query = +{
        query => {
            terms => {
                pauseid =>
                    [ map { $_->{pauseid} ? $_->{pauseid} : () } @contribs ]
            }
        }
    };

    my $contrib_authors = $self->es->search(
        index => $self->index_name,
        type  => 'author',
        body  => {
            query   => $contrib_query,
            size    => 999,
            _source => [qw< pauseid gravatar_url >],
        }
    );

    my %id2url = map { $_->{_source}{pauseid} => $_->{_source}{gravatar_url} }
        @{ $contrib_authors->{hits}{hits} };
    for my $contrib (@contribs) {
        next unless $contrib->{pauseid};
        $contrib->{gravatar_url} = $id2url{ $contrib->{pauseid} }
            if exists $id2url{ $contrib->{pauseid} };
    }

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
        index => $self->index_name,
        type  => 'file',
        body  => {
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

    my $query = +{ query => { term => { name => $release } } };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => {
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
        = ( { range => { date => { from => $start->epoch . '000' } } } );

    push @filters, +{ term => { author => uc($author) } }
        if $author;

    push @filters, +{ term => { distribution => $distribution } }
        if $distribution;

    push @filters, +{ term => { 'dependency.module' => $module } }
        if $module;

    if ( $new_dists and $new_dists eq 'n' ) {
        push @filters,
            (
            +{ term  => { first  => 1 } },
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

    my $body = {
        query        => { match_all => {} },
        aggregations => {
            histo => {
                filter       => $filters,
                aggregations => {
                    entries => {
                        date_histogram =>
                            { field => 'date', interval => $res },
                    }
                }
            }
        },
        size => 0,
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

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

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

    my $data = $ret->{hits}{hits}[0]{_source};
    single_valued_arrayref_to_scalar($data);

    return {
        took    => $ret->{took},
        release => $data,
        total   => $ret->{hits}{total}
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
                            query => {
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
                        }
                    } @$releases
                ]
            }
        }
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

    my @releases;
    for my $hit ( @{ $ret->{hits}{hits} } ) {
        my $src = $hit->{_source};
        single_valued_arrayref_to_scalar($src);
        push @releases, $src;
    }

    return {
        took     => $ret->{took},
        total    => $ret->{hits}{total},
        releases => \@releases,
    };
}

sub by_author {
    my ( $self, $pauseid, $size, $page ) = @_;
    $size //= 1000;
    $page //= 1;

    my $body = {
        query => {
            bool => {
                must => [
                    { terms => { status => [qw< cpan latest >] } },
                    ( $pauseid ? { term => { author => $pauseid } } : () ),
                ],
            }
        },
        sort =>
            [ 'distribution', { 'version_numified' => { reverse => 1 } } ],
        _source => [
            qw( abstract author authorized date distribution license metadata.version resources.repository status tests )
        ],
        size => $size,
        from => ( $page - 1 ) * $size,
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

    my $data = [ map { $_->{_source} } @{ $ret->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($data);

    return {
        releases => $data,
        total    => $ret->{hits}{total},
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

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

    my $data = $ret->{hits}{hits}[0]{_source};
    single_valued_arrayref_to_scalar($data);

    return {
        release => $data,
        took    => $ret->{took},
        total   => $ret->{hits}{total}
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
        sort =>
            [ 'distribution', { 'version_numified' => { reverse => 1 } } ],
        fields => [
            qw(author distribution name status abstract date download_url version authorized maturity)
        ],
        size => 1000,
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

    my $data = [ map { $_->{fields} } @{ $ret->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($data);

    return { took => $ret->{took}, releases => $data };
}

sub all_by_author {
    my ( $self, $author, $size, $page ) = @_;
    $size //= 100;
    $page //= 1;

    my $body = {
        query  => { term => { author => uc($author) } },
        sort   => [ { date => 'desc' } ],
        fields => [
            qw(author distribution name status abstract date download_url version authorized maturity)
        ],
        size => $size,
        from => ( $page - 1 ) * $size,
    };
    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

    my $data = [ map { $_->{fields} } @{ $ret->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($data);

    return {
        took     => $ret->{took},
        releases => $data,
        total    => $ret->{hits}{total}
    };
}

sub versions {
    my ( $self, $dist, $versions ) = @_;

    my $size = $dist eq 'perl' ? 1000 : 250;

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
        query  => $query,
        size   => $size,
        sort   => [ { date => 'desc' } ],
        fields => [
            qw( name date author version status maturity authorized download_url)
        ],
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

    my $data = [ map { $_->{fields} } @{ $ret->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($data);

    return {
        releases => $data,
        total    => $ret->{hits}{total},
        took     => $ret->{took}
    };
}

sub top_uploaders {
    my ( $self, $range ) = @_;
    my $range_filter = {
        range => {
            date => {
                from => $range eq 'all' ? 0 : DateTime->now->subtract(
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

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

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
        $page_size, $sort );
}

sub reverse_dependencies {
    my ( $self, $distribution, $page, $page_size, $size, $sort ) = @_;

    # get the latest release of given distribution
    my $release = $self->_get_latest_release($distribution) || return;

    # get (authorized/indexed) modules provided by the release
    my $modules = $self->_get_provided_modules($release) || return;

    # return releases depended on those modules
    return $self->_get_depended_releases( $modules, $page, $page_size,
        $size, $sort );
}

sub _get_latest_release {
    my ( $self, $distribution ) = @_;

    my $release = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => {
            query => {
                bool => {
                    must => [
                        { term => { distribution => $distribution } },
                        { term => { status       => 'latest' } },
                        { term => { authorized   => 1 } },
                    ]
                },
            },
            fields => [qw< name author >],
        },
    );

    my ($release_info) = map { $_->{fields} } @{ $release->{hits}{hits} };
    single_valued_arrayref_to_scalar($release_info);

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
        index => $self->index_name,
        type  => 'file',
        body  => {
            query => {
                bool => {
                    must => [
                        { term => { 'release' => $release->{name} } },
                        { term => { 'author'  => $release->{author} } },
                        { term => { 'module.authorized' => 1 } },
                        { term => { 'module.indexed'    => 1 } },
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
    my ( $self, $modules, $page, $page_size, $size, $sort ) = @_;
    $page      //= 1;
    $page_size //= 50;

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
        index => $self->index_name,
        type  => 'release',
        body  => {
            query => {
                bool => {
                    must => [
                        $dependency_filter,
                        { term => { status     => 'latest' } },
                        { term => { authorized => 1 } },
                    ],
                },
            },
            size => $size || $page_size,
            from => $page * $page_size - $page_size,
            sort => $sort,
        }
    );

    return +{
        data  => [ map { $_->{_source} } @{ $depended->{hits}{hits} } ],
        total => $depended->{hits}{total},
        took  => $depended->{took},
    };
}

sub recent {
    my ( $self, $page, $page_size, $type ) = @_;
    $page      //= 1;
    $page_size //= 10000;
    $type      //= '';

    my $query;
    my $from = ( $page - 1 ) * $page_size;

    if ( $from + $page_size > 10000 ) {
        return {
            releases => [],
            total    => 0,
            took     => 0,
        };
    }

    if ( $type eq 'n' ) {
        $query = {
            constant_score => {
                filter => {
                    bool => {
                        must => [
                            { term  => { first  => 1 } },
                            { terms => { status => [qw< cpan latest >] } },
                        ]
                    }
                }
            }
        };
    }
    elsif ( $type eq 'a' ) {
        $query = { match_all => {} };
    }
    else {
        $query = {
            constant_score => {
                filter => {
                    terms => { status => [qw< cpan latest >] }
                }
            }
        };
    }

    my $body = {
        size   => $page_size,
        from   => $from,
        query  => $query,
        fields =>
            [qw(name author status abstract date distribution maturity)],
        sort => [ { 'date' => { order => 'desc' } } ]
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'release',
        body  => $body,
    );

    my $data = [ map { $_->{fields} } @{ $ret->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($data);

    return {
        releases => $data,
        total    => $ret->{hits}{total},
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
                    { term => { directory => 0 } },
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
                                                term =>
                                                    { 'module.indexed' => 1 }
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
                                                term => { 'indexed' => 1 }
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

        _source => [ "module", "abstract" ],

        fields => [ qw(
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

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'file',
        body  => $body,
    );

    my @files = map +{
        %{ ( single_valued_arrayref_to_scalar( $_->{fields} ) )[0] },
        %{ $_->{_source} }
        },
        @{ $ret->{hits}{hits} };

    return {
        files => \@files,
        total => $ret->{hits}{total},
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
        push @filters, { not => { term => { status => 'backpan' } } };
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
                { term => { $prefix . 'authorized' => 1 } },
                (
                    $module_filter
                    ? (
                        { term => { $prefix . 'indexed' => 1 } },
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
                ? ( must_not => [ $version_filters->{must_not} ] )
                : ()
            )
        }
    };

    # filters to be applied to the nested modules
    if ($module_filter) {
        push @filters,
            {
            nested => {
                path       => 'module',
                inner_hits => { _source => 'version' },
                filter     => $entity_filter,
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
            mode          => 'max',
            order         => 'desc',
            nested_path   => 'module',
            nested_filter => $entity_filter,
        }
        }
        : { version_numified => { order => 'desc' } };

    # sort by score, then version desc, then date desc
    my @sort = ( '_score', $version_sort, { date => { order => 'desc' } } );

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

    my $body = {
        query   => $query,
        size    => 1,
        sort    => \@sort,
        _source => [ qw(
            checksum_md5
            checksum_sha256
            date
            download_url
            release
            status
            version
            name
        ) ],
    };

    my $res = $self->es->search(
        index       => $self->index_name,
        type        => $module_filter ? 'file' : 'release',
        body        => $body,
        search_type => 'dfs_query_then_fetch',
    );

    return unless $res->{hits}{total};

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
        index => $self->index_name,
        type  => 'release',
        body  => {
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
        index => $self->index_name,
        type  => 'release',
        body  => {
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
