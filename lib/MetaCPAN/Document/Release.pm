package MetaCPAN::Document::Release;

use strict;
use warnings;

use Moose;
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

sub find_depending_on {
    my ( $self, $modules ) = @_;
    return $self->filter(
        {
            or => [
                map { { term => { 'dependency.module' => $_ } } } @$modules
            ]
        }
    );
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
    my ( $self, $dist ) = @_;

    my $query = +{
        query => {
            bool => {
                must => [
                    { term => { distribution => $dist } },
                    { term => { status       => 'latest' } },
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
            _source => [qw< author metadata.author metadata.x_contributors >],
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

    my $author = $self->es->get(
        index => $self->index->name,
        type  => 'author',
        id    => $release->{author},
    );

    my $author_email = $author->{_source}{email};
    my $author_info  = {
        email => [
            lc "$release->{author}\@cpan.org",
            (
                Ref::Util::is_arrayref($author_email)
                ? @{$author_email}
                : $author_email
            ),
        ],
        name         => $author->{_source}{name},
        gravatar_url => $author->{_source}{gravatar_url},
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
        $contrib->{gravatar_url} = $id2url{ $contrib->{pauseid} }
            if exists $id2url{ $contrib->{pauseid} };
    }

    return { contributors => \@contribs };
}

__PACKAGE__->meta->make_immutable;
1;
