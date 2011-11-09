package MetaCPAN::Document::Module;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Util;

=head1 SYNOPSIS

MetaCPAN::Document::Module->new(
                                 { name             => "Some::Module",
                                   version          => "1.1.1"
                                 } );


=head1 PROPERTIES

=head2 name

B<Required>

=head2 name.analyzed

=head2 name.camelcase

Name of the module. When searching for a module it is advised to use use both
the C<analyzed> and the C<camelcase> property.

=head2 version

Contains the raw version string.

=head2 version_numified

B<Required>, B<Lazy Build>

Numified version of L</version>. Contains 0 if there is no version or the
version could not be parsed.

=head2 indexed

B<Default 0>

Indicates whether the module should be included in the search index or
not. Releases usually exclude modules in folders like C<t/> or C<example/>
from the index.

=head1 METHODS

=head2 hide_from_pause( $content )

Using this pragma, you can hide a module from the CPAN indexer:

 package # hide me
   Foo;

This methods searches C<$content> for the package declaration. If it's
not declared in one line, the module is considered not-indexed.

=cut

has name => (
    is       => 'ro',
    required => 1,
    index    => 'analyzed',
    analyzer => [qw(standard camelcase lowercase)],
);
has version => ( is => 'ro' );
has version_numified =>
    ( is => 'ro', isa => 'Num', lazy_build => 1, required => 1 );
has indexed    => ( is => 'rw', required => 1, isa => 'Bool', default => 0 );
has authorized => ( is => 'ro', required => 1, isa => 'Bool', default => 1 );

sub _build_version_numified {
    my $self = shift;
    return 0 unless ( $self->version );
    return MetaCPAN::Util::numify_version( $self->version );
}

sub hide_from_pause {
    my ( $self, $content ) = @_;
    my $pkg = $self->name;
    return $content =~ /    # match a package declaration
      ^[\h\{;]*             # intro chars on a line
      package               # the word 'package'
      \h+                   # whitespace
      ($pkg)                # a package name
      \h*                   # optional whitespace
      (.+)?                 # optional version number
      \h*                   # optional whitesapce
      ;                     # semicolon line terminator
    /mx ? 0 : 1;
}

__PACKAGE__->meta->make_immutable;
