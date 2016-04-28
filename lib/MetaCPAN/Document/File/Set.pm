package MetaCPAN::Document::File::Set;

use Moose;

extends 'ElasticSearchX::Model::Document::Set';

my @ROGUE_DISTRIBUTIONS = qw(
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
    my @candidates = $self->index->type('file')->filter(
        {
            bool => {
                must => [
                    { term => { 'indexed'    => \1, } },
                    { term => { 'authorized' => \1 } },
                    { term => { 'status'     => 'latest', } },
                ],
                should => [
                    { term => { 'documentation' => $module } },
                    {
                        nested => {
                            path => 'module',
                            filter =>
                                { term => { 'module.name' => $module } },
                        }
                    }
                ]
            }
        }
        )->sort(
        [
            { 'date'       => { order => 'desc' } },
            { 'mime'       => { order => 'asc' } },
            { 'stat.mtime' => { order => 'desc' } }
        ]
        )->size(100)->all;

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

# return files that contain modules that match the given dist
# NOTE: these still need to be filtered by authorized/indexed
# TODO: test that we are getting the correct version (latest)
sub find_provided_by {
    my ( $self, $release ) = @_;
    return $self->filter(
        {
            bool => {
                must => [
                    { term => { 'release' => $release->{name} } },
                    { term => { 'author'  => $release->{author} } },
                    { term => { 'file.module.authorized' => 1 } },
                    { term => { 'file.module.indexed'    => 1 } },
                ]
            }
        }
    )->size(999)->all;
}

# filter find_provided_by results for indexed/authorized modules
# and return a list of package names
sub find_module_names_provided_by {
    my ( $self, $release ) = @_;
    my $mods = $self->inflate(0)->find_provided_by($release);
    return (
        map { $_->{name} }
        grep { $_->{indexed} && $_->{authorized} }
        map { @{ $_->{_source}->{module} } } @{ $mods->{hits}->{hits} }
    );
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

    # filters to be applied to the nested modules
    my $module_f = {
        nested => {
            path       => 'module',
            inner_hits => { _source => 'version' },
            filter     => {
                bool => {
                    must => [
                        { term => { 'module.authorized' => \1 } },
                        { term => { 'module.indexed'    => \1 } },
                        { term => { 'module.name'       => $module } },
                        $self->_version_filters($version)
                    ]
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

    return $self->size(1)->query($query)
        ->source( [ 'download_url', 'date', 'status' ] )->sort( \@sort );

}

sub _version_filters {
    my ( $self, $version ) = @_;

    return () unless $version;

    if ( $version =~ s/^==\s*// ) {
        return { term => { 'module.version' => $version }, };
    }
    elsif ( $version !~ /\s/ ) {
        return {
            range => {
                'module.version_numified' =>
                    { 'gte' => $self->_numify($version) }
            },
        };
    }
    else {
        my %ops = qw(< lt <= lte > gt >= gte);
        my ( %range, @exclusion );
        my @requirements = split /,\s*/, $version;
        for my $r (@requirements) {
            if ( $r =~ s/^([<>]=?)\s*// ) {
                $range{ $ops{$1} } = $self->_numify($r);
            }
            elsif ( $r =~ s/\!=\s*// ) {
                push @exclusion, $self->_numify($r);
            }
        }

        my @filters
            = ( { range => { 'module.version_numified' => \%range } }, );

        if (@exclusion) {
            push @filters, {
                not => {
                    or => [
                        map {
                            +{
                                term => {
                                    'module.version_numified' =>
                                        $self->_numify($_)
                                }
                                }
                        } @exclusion
                    ]
                },
            };
        }

        return @filters;
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
        = $type eq 'module' ? $self->filter(
        {
            nested => {
                path  => 'module',
                query => {
                    constant_score => {
                        filter => {
                            bool => {
                                must => [
                                    { term => { 'module.authorized' => \1 } },
                                    { term => { 'module.indexed'    => \1 } },
                                    { term => { 'module.name' => $module } },
                                ]
                            }
                        }
                    }
                }
            }
        }
        )
        : $type eq 'file' ? $self->filter(
        {
            bool => {
                must => [
                    { term => { 'file.path' => join( '/', @path ) } },
                    { term => { 'file.distribution' => $module } },
                ]
            }
        }
        )
        : $self->filter(
        {
            bool => {
                must => [
                    { term => { 'file.documentation' => $module } },
                    { term => { 'file.indexed'       => \1 } },
                    { term => { 'file.authorized'    => \1 } },
                ]
            }
        }
        );
    return $search->sort( [ { date => 'desc' } ] );
}

sub autocomplete {
    my ( $self, @terms ) = @_;
    my $query = join( q{ }, @terms );
    return $self unless $query;

    return $self->search_type('dfs_query_then_fetch')->query(
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
                            { exists => { field        => 'documentation' } },
                            { term   => { 'indexed'    => \1 } },
                            { term   => { 'status'     => 'latest' } },
                            { term   => { 'authorized' => \1 } }
                        ],
                        must_not => [
                            {
                                terms => {
                                    'distribution' => \@ROGUE_DISTRIBUTIONS
                                }
                            },
                        ],
                    }
                }
            }
        }
    )->sort( [ '_score', 'documentation' ] );
}

__PACKAGE__->meta->make_immutable;
1;
