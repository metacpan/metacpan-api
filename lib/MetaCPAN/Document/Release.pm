package MetaCPAN::Document::Release;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Document::Author;
use MetaCPAN::Types qw(:all);
use MetaCPAN::Util;

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

Name of the tarball (e.g. C<Some-Module-1.12.tar.gz>).

=head2 date

B<Required>

Release date (i.e. C<mtime> of the tarball).

=head2 version

Contains the raw version string.

=head2 version_numified

Numified version of L</version>. Contains 0 if there is no version or the
version could not be parsed.

=head2 status

Valid values are C<latest>, C<cpan>, and C<backpan>. The most recent upload
of a distribution is tagged as C<latest> as long as it's not a developer
release, unless there are only developer releases. Everything else is
tagged C<cpan>. Once a release is deleted from PAUSE it is tagged as
C<backpan>.

=head2 maturity

Maturity of the release. This can either be C<released> or C<developer>.
See L<CPAN::DistnameInfo>.

=head2 dependency

Array of dependencies as derived from the META file.
See L<MetaCPAN::Document::Dependency>.

=head2 resources

See L<CPAN::Meta::Spec/resources>.

=head2 abstract

Description of the release.

=head2 license

See L<CPAN::Meta::Spec/license>.

=head2 stat

L<File::stat> info of the tarball. Contains C<mode>, C<uid>, C<gid>, C<size>
and C<mtime>.



=cut

has id => ( is => 'ro', id => [qw(author name)] );
has [qw(license version author archive)] => ( is => 'ro', required => 1 );
has date         => ( is => 'ro', required => 1, isa        => 'DateTime' );
has download_url => ( is => 'ro', required => 1, lazy_build => 1 );
has [qw(distribution name)] => (
    is       => 'ro',
    required => 1,
    analyzer => [qw(standard camelcase lowercase)],
);
has version_numified =>
    ( is => 'ro', required => 1, isa => 'Num', lazy_build => 1 );
has resources => (
    is              => 'ro',
    isa             => Resources,
    coerce          => 1,
    dynamic         => 1,
    type            => 'nested',
    include_in_root => 1,
);
has abstract => ( is => 'ro', index => 'analyzed' );
has dependency => (
    required        => 0,
    is              => 'rw',
    isa             => Dependency,
    coerce          => 1,
    type            => 'nested',
    include_in_root => 1,
);
has status   => ( is => 'rw', required => 1, default => 'cpan' );
has maturity => ( is => 'ro', required => 1, default => 'released' );
has stat  => ( is => 'ro', isa => Stat,  dynamic => 1 );
has tests => ( is => 'ro', isa => Tests, dynamic => 1 );
has authorized => ( is => 'ro', required => 1, isa => 'Bool', default => 1 );
has first => (
    is       => 'ro',
    required => 1,
    isa      => 'Bool',
    lazy     => 1,
    builder  => '_build_first'
);

sub _build_version_numified {
    return MetaCPAN::Util::numify_version( shift->version );
}

sub _build_download_url {
    my $self = shift;
    return
          'http://cpan.metacpan.org/authors/'
        . MetaCPAN::Document::Author::_build_dir( $self->author ) . '/'
        . $self->archive;
}

sub _build_first {
    my $self = shift;
    $self->index->type('release')
        ->filter(
        { term => { 'release.distribution' => $self->distribution } } )->count
        ? 0
        : 1;
}

__PACKAGE__->meta->make_immutable;

package MetaCPAN::Document::Release::Set;
use Moose;
extends 'ElasticSearchX::Model::Document::Set';

sub find {
    my ( $self, $name ) = @_;
    return $self->filter(
        {   and => [
                { term => { 'release.distribution' => $name } },
                { term => { status                 => 'latest' } }
            ]
        }
    )->sort( [ { date => 'desc' } ] )->first;
}

sub predecessor {
    my ( $self, $name ) = @_;
    return $self->filter(
        {   and => [
                { term => { 'release.distribution' => $name } },
                { not => { filter => { term => { status => 'latest' } } } },
            ]
        }
    )->sort( [ { date => 'desc' } ] )->first;
}

__PACKAGE__->meta->make_immutable;
