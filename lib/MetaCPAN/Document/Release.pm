package MetaCPAN::Document::Release;

use strict;
use warnings;

use Moose;
use DateTime qw();
use Ref::Util qw();
use ElasticSearchX::Model::Document;

use MetaCPAN::Types qw(:all);
use MetaCPAN::Util qw( numify_version );

=head1 PROPERTIES

=head2 id

Unique identifier of the release. Consists of the L</author>'s pauseid and
the release L</name>. See L</ElasticSearchX::Model::Util::digest>.

=head2 name

=head2 name.analyzed

Name of the release (e.g. C<Some-Module-1.12>).

=head2 distribution

=head2 distribution.analyzed

=head2 distribution.camelcase

Name of the distribution (e.g. C<Some-Module>).

=head2 author

PAUSE ID of the author.

=head2 archive

Name of the archive file (e.g. C<Some-Module-1.12.tar.gz>).

=head2 date

B<Required>

Release date (i.e. C<mtime> of the archive file).

=head2 version

Contains the raw version string.

=head2 version_numified

Numified version of L</version>. Contains 0 if there is no version or the
version could not be parsed.

=head2 status

Valid values are C<latest>, C<cpan>, and C<backpan>. The most recent upload
of a distribution is tagged as C<latest> as long as it's not a developer
release. Everything else is tagged C<cpan>. Once a release is deleted from
PAUSE it is tagged as C<backpan>.

=head2 maturity

Maturity of the release. This can either be C<released> or C<developer>.
See L<CPAN::DistnameInfo>.

=head2 dependency

Array of dependencies as derived from the META file.
See L<MetaCPAN::Document::Dependency>.

=head2 resources

See L<CPAN::Meta::Spec/resources>.

=head2 meta

See L<CPAN::Meta/as_struct>. Upgraded to version 2 if possible. This property
is not indexed by ElasticSearch and only available from the source.

=head2 abstract

Description of the release.

=head2 license

See L<CPAN::Meta::Spec/license>.

=head2 stat

L<File::stat> info of the archive file. Contains C<mode>,
C<size> and C<mtime>.

=head2 first

B<Boolean>; Indicates whether this is the first ever release for this distribution.

=head2 provides

This is an ArrayRef of modules that are included in this release.

=cut

has provides => (
    is     => 'ro',
    isa    => ArrayRef [Str],
    writer => '_set_provides',
);

has id => (
    is => 'ro',
    id => [qw(author name)],
);

has [qw(version author archive)] => (
    is       => 'ro',
    required => 1,
);

has license => (
    is       => 'ro',
    isa      => ArrayRef,
    required => 1,
);

has date => (
    is       => 'ro',
    required => 1,
    isa      => 'DateTime',
);

has download_url => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_download_url',
);

has [qw(distribution name)] => (
    is       => 'ro',
    required => 1,
    analyzer => [qw(standard camelcase lowercase)],
);

has version_numified => (
    required => 1,
    is       => 'ro',
    isa      => Num,
    lazy     => 1,
    default  => sub {
        return numify_version( shift->version );
    },
);

has resources => (
    is              => 'ro',
    isa             => Resources,
    coerce          => 1,
    dynamic         => 1,
    type            => 'nested',
    include_in_root => 1,
);

has abstract => (
    is        => 'ro',
    index     => 'analyzed',
    predicate => 'has_abstract',
    writer    => '_set_abstract',
);

has dependency => (
    is              => 'ro',
    isa             => Dependency,
    coerce          => 1,
    type            => 'nested',
    include_in_root => 1,
);

# The initial state for a release is 'cpan'.
# The indexer scripts will upgrade it to 'latest' if it's the version in
# 02packages or downgrade it to 'backpan' if it gets deleted.
has status => (
    is       => 'ro',
    required => 1,
    default  => 'cpan',
    writer   => '_set_status',
);

has maturity => (
    is       => 'ro',
    required => 1,
    default  => 'released',
);

has stat => (
    is      => 'ro',
    isa     => Stat,
    dynamic => 1,
);

has tests => (
    is            => 'ro',
    isa           => Tests,
    dynamic       => 1,
    documentation => 'HashRef: Summary of CPANTesters data',
);

has authorized => (
    is       => 'ro',
    required => 1,
    isa      => Bool,
    default  => 1,
    writer   => '_set_authorized',
);

has first => (
    is       => 'ro',
    required => 1,
    isa      => Bool,
    default  => 0,
    writer   => '_set_first',
);

has metadata => (
    coerce      => 1,
    is          => 'ro',
    isa         => HashRef,
    dynamic     => 1,
    source_only => 1,
);

has main_module => (
    is     => 'ro',
    isa    => Str,
    writer => '_set_main_module',
);

has changes_file => (
    is     => 'ro',
    isa    => Str,
    writer => '_set_changes_file',
);

sub _build_download_url {
    my $self = shift;
    return
          'https://cpan.metacpan.org/authors/'
        . MetaCPAN::Util::author_dir( $self->author ) . '/'
        . $self->archive;
}

sub set_first {
    my $self     = shift;
    my $is_first = $self->index->type('release')->filter(
        {
            and => [
                { term => { distribution => $self->distribution } },
                {
                    range => {
                        version_numified =>
                            { 'lt' => $self->version_numified }
                    }
                },

          # REINDEX: after a full reindex, the above line is to replaced with:
          # { term => { first => 1 } },
          # currently, the "first" property is not computed on all releases
          # since this feature has not been around when last reindexed
            ]
        }
        )->count
        ? 0
        : 1;

    $self->_set_first($is_first);
}

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Document::Release::Set;

use strict;
use warnings;

use Moose;

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

extends 'ElasticSearchX::Model::Document::Set';

sub aggregate_status_by_author {
    my ( $self, $pauseid ) = @_;
    my $agg = $self->es->search(
        {
            index => $self->index->name,
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
        }
    );
    my %ret = ( cpan => 0, latest => 0, backpan => 0 );
    if ($agg) {
        $ret{ $_->{'key'} } = $_->{'doc_count'}
            for @{ $agg->{'aggregations'}{'count'}{'buckets'} };
    }
    $ret{'backpan-only'} = delete $ret{'backpan'};
    return \%ret;
}

sub find {
    my ( $self, $name ) = @_;
    return $self->filter(
        {
            and => [
                { term => { distribution => $name } },
                { term => { status       => 'latest' } }
            ]
        }
    )->sort( [ { date => 'desc' } ] )->first;
}

sub predecessor {
    my ( $self, $name ) = @_;
    return $self->filter(
        {
            and => [
                { term => { distribution => $name } },
                { not => { filter => { term => { status => 'latest' } } } },
            ]
        }
    )->sort( [ { date => 'desc' } ] )->first;
}

sub find_github_based {
    shift->filter(
        {
            and => [
                { term => { status => 'latest' } },
                {
                    or => [
                        {
                            prefix => {
                                "resources.bugtracker.web" =>
                                    'http://github.com/'
                            }
                        },
                        {
                            prefix => {
                                "resources.bugtracker.web" =>
                                    'https://github.com/'
                            }
                        },
                    ]
                }
            ]
        }
    );
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
        index => $self->index->name,
        type  => 'release',
        body  => {
            query   => $query,
            size    => 999,
            _source => [qw< metadata.author metadata.x_contributors >],
        }
    );

    my $release  = $res->{hits}{hits}[0]{_source};
    my $contribs = $release->{metadata}{x_contributors} || [];
    my $authors  = $release->{metadata}{author} || [];

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
        index => $self->index->name,
        type  => 'author',
        id    => $author_name,
        );

    my $author = $self->es->get(
        index => $self->index->name,
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
        index => $self->index->name,
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
        index => $self->index->name,
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
        index => $self->index->name,
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
        index => $self->index->name,
        type  => 'release',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my $data = [ map { $_->{_source} } @{ $ret->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($data);

    return {
        took     => $ret->{took},
        releases => $data,
        total    => $ret->{hits}{total}
    };
}

sub by_author {
    my ( $self, $pauseid, $size ) = @_;
    $size //= 1000;

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
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'release',
        body  => $body,
    );
    return unless $ret->{hits}{total};

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
        index => $self->index->name,
        type  => 'release',
        body  => $body,
    );
    return unless $ret->{hits}{total};

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
        fields => [qw(author distribution name status abstract date)],
        size   => 1000,
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'release',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my $data = [ map { $_->{fields} } @{ $ret->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($data);

    return { took => $ret->{took}, releases => $data };
}

sub all_by_author {
    my ( $self, $author, $size, $page ) = @_;
    $size //= 100;
    $page //= 1;

    my $body = {
        query => { term => { author => uc($author) } },
        sort  => [      { date      => 'desc' } ],
        fields => [qw(author distribution name status abstract date)],
        size   => $size,
        from   => ( $page - 1 ) * $size,
    };
    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'release',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my $data = [ map { $_->{fields} } @{ $ret->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($data);

    return {
        took     => $ret->{took},
        releases => $data,
        total    => $ret->{hits}{total}
    };
}

sub versions {
    my ( $self, $dist ) = @_;

    my $body = {
        query => { term => { distribution => $dist } },
        size  => 250,
        sort  => [      { date            => 'desc' } ],
        fields => [qw( name date author version status maturity authorized )],
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'release',
        body  => $body,
    );
    return unless $ret->{hits}{total};

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
        index => $self->index->name,
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
    $page      //= 1;
    $page_size //= 20;
    $sort      //= { date => 'desc' };

    my $query = {
        query => {
            filtered => {
                query  => { 'match_all' => {} },
                filter => {
                    and => [
                        { term => { 'status'     => 'latest' } },
                        { term => { 'authorized' => 1 } },
                        {
                            term => {
                                'dependency.module' => $module
                            }
                        }
                    ]
                }
            }
        }
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'release',
        body  => {
            query => $query,
            from  => $page * $page_size - $page_size,
            size  => $page_size,
            sort  => [$sort],
        }
    );
    return {} unless $ret->{hits}{total};

    return +{
        data => [ map { $_->{_source} } @{ $ret->{hits}{hits} } ],
        total => $ret->{hits}{total},
        took  => $ret->{took}
    };
}

sub reverse_dependencies {
    my ( $self, $distribution, $page, $page_size, $sort ) = @_;

    # get the latest release of given distribution
    my $release = $self->_get_latest_release($distribution) || return;

    # get (authorized/indexed) modules provided by the release
    my $modules = $self->_get_provided_modules($release) || return;

    # get releases depended on those modules
    my $depended
        = $self->_get_depended_releases( $modules, $page, $page_size, $sort )
        || return;

    return +{ data => $depended };
}

sub _get_latest_release {
    my ( $self, $distribution ) = @_;

    my $release = $self->es->search(
        index => $self->index->name,
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
    return unless $release->{hits}{total};

    my ($release_info) = map { $_->{fields} } @{ $release->{hits}{hits} };
    single_valued_arrayref_to_scalar($release_info);

    return +{
        name   => $release_info->{name},
        author => $release_info->{author},
    };
}

sub _get_provided_modules {
    my ( $self, $release ) = @_;

    my $provided_modules = $self->es->search(
        index => $self->index->name,
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
    return unless $provided_modules->{hits}{total};

    return [
        map { $_->{name} }
            grep { $_->{indexed} && $_->{authorized} }
            map { @{ $_->{_source}{module} } }
            @{ $provided_modules->{hits}{hits} }
    ];
}

sub _get_depended_releases {
    my ( $self, $modules, $page, $page_size, $sort ) = @_;
    $sort //= { date => 'desc' };
    $page //= 1;
    $page_size //= 50;

    # because 'terms' doesn't work properly
    my $filter_modules = {
        bool => {
            should => [
                map +{ term => { 'dependency.module' => $_ } },
                @{$modules}
            ]
        }
    };

    my $depended = $self->es->search(
        index => $self->index->name,
        type  => 'release',
        body  => {
            query => {
                bool => {
                    must => [
                        $filter_modules,
                        { term => { status     => 'latest' } },
                        { term => { authorized => 1 } },
                    ]
                }
            },
            size => $page_size,
            from => $page * $page_size - $page_size,
            sort => $sort,
        }
    );
    return unless $depended->{hits}{total};

    return [ map { $_->{_source} } @{ $depended->{hits}{hits} } ];
}

sub recent {
    my ( $self, $page, $page_size, $type ) = @_;
    my $query;

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
        from   => ( $page - 1 ) * $page_size,
        query  => $query,
        fields => [qw(name author status abstract date distribution)],
        sort   => [ { 'date' => { order => 'desc' } } ]
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'release',
        body  => $body,
    );
    return unless $ret->{hits}{total};

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

        fields => [
            qw(
                author
                authorized
                distribution
                documentation
                indexed
                path
                pod_lines
                release
                status
                )
        ],
    };

    my $ret = $self->es->search(
        index => $self->index->name,
        type  => 'file',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my @files = map { single_valued_arrayref_to_scalar($_) }
        map +{ %{ $_->{fields} }, %{ $_->{_source} } },
        @{ $ret->{hits}{hits} };

    return {
        files => \@files,
        total => $ret->{hits}{total},
        took  => $ret->{took}
    };
}

__PACKAGE__->meta->make_immutable;
1;
