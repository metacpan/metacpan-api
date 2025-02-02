package MetaCPAN::Document::Module;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document;

with 'ElasticSearchX::Model::Document::EmbeddedRole';

use MetaCPAN::Types           qw( ESBool );
use MetaCPAN::Types::TypeTiny qw( Maybe Num Str );
use MetaCPAN::Util            qw(true false);

=head1 SYNOPSIS

    MetaCPAN::Document::Module->new(
        {
            name    => "Some::Module",
            version => "1.1.1"
        }
    );


=head1 PROPERTIES

=head2 name

B<Required>

=head2 name.analyzed

=head2 name.camelcase

Name of the module. When searching for a module it is advised to use use both
the C<analyzed> and the C<camelcase> property.

=head2 version

Contains the raw version string.

=head2 indexed

B<Default 0>

Indicates whether the module should be included in the search index or
not. Releases usually exclude modules in folders like C<t/> or C<example/>
from the index.

=head1 METHODS

=head2 hide_from_pause( $content, $file_name )

Using this pragma, you can hide a module from the CPAN indexer:

 package # hide me
   Foo;

This methods searches C<$content> for the package declaration. If it's
not declared in one line, the module is considered not-indexed.

=cut

has name => (
    is       => 'ro',
    isa      => Str,
    required => 1,
    index    => 'analyzed',
    analyzer => [qw(standard camelcase lowercase)],
);

has version => ( is => 'ro' );

has indexed => (
    is       => 'ro',
    required => 1,
    isa      => ESBool,
    default  => sub {true},
    writer   => '_set_indexed',
);

has authorized => (
    is       => 'ro',
    required => 1,
    isa      => ESBool,
    default  => sub {true},
    writer   => '_set_authorized',
);

has associated_pod => (
    required => 1,
    isa      => Maybe [Str],
    is       => 'ro',
    default  => sub { },
    writer   => '_set_associated_pod',
);

has version_numified => (
    is         => 'ro',
    isa        => Num,
    lazy_build => 1,
    required   => 1,
);

sub _build_version_numified {
    my $self = shift;
    return 0 unless ( $self->version );
    return MetaCPAN::Util::numify_version( $self->version );
}

my $bom
    = qr/(?:\x00\x00\xfe\xff|\xff\xfe\x00\x00|\xfe\xff|\xff\xfe|\xef\xbb\xbf)/;

sub hide_from_pause {
    my ( $self, $content, $file_name ) = @_;
    return 0 if defined($file_name) && $file_name =~ m{\.pm\.PL\z};
    my $pkg       = $self->name;
    my $pkg_match = join q[(?:::|')], map quotemeta, split m{::}, $pkg;

# This regexp is *almost* the same as $PKG_REGEXP in Module::Metadata.
# [b] We need to allow/ignore a possible BOM since we read in binary mode.
# Module::Metadata, for example, checks for a BOM and then sets the encoding.
# [s] We change `\s` to `\h` because we want to verify that it's on one line.
# [p] We replace $PKG_NAME_REGEXP with the specific package we're looking for.
# [v] Simplify the optional whitespace/version group ($V_NUM_REGEXP).
    return $content =~ /    # match a package declaration
      ^                     # start of line
       (?:\A$bom)?          # possible BOM at the start of the file [b]
       [\h\{;]*             # intro chars on a line [s]
      package               # the word 'package'
      \h+                   # whitespace [s]
      ($pkg_match)          # the package name [p]
      (\h+ v?[0-9._]+)?     # optional version number (preceded by whitespace) [v]
      \h*                   # optional whitesapce [s]
      [;\{]                 # semicolon line terminator or block start
    /mx ? 0 : 1;
}

=head2 set_associated_pod

Expects an instance C<$file> of L<MetaCPAN::Document::File> as first parameter
and a HashRef C<$pod> which contains all files with a L<MetaCPAN::Document::File/documentation>
and maps those to the file names.

L</associated_pod> is set to the path of the file, which contains the documentation.

=cut

my %_pod_score = (
    pod => 50,
    pm  => 40,
    pl  => 30,
);

sub set_associated_pod {
    my ( $self, $associated_pod ) = @_;
    return unless ( my $files = $associated_pod->{ $self->name } );

    ( my $mod_path = $self->name ) =~ s{::}{/}g;

    my ($file) = (
        #<<<
        # TODO: adjust score if all files are in root?
        map  { $_->[1] }
        sort { $b->[0] <=> $a->[0] }    # desc
        map  {
            [ (
                # README.pod in root should rarely if ever be chosen.
                # Typically it's there for github or something and it's usually
                # a duplicate of the main module pod (though sometimes it falls
                # out of sync (which makes it even worse)).
                $_->path =~ /^README\.pod$/i ? -10 :

                # If the name of the package matches the name of the file,
                $_->path =~ m!(^lib/)?\b${mod_path}.((?i)pod|pm)$! ?
                    # Score pod over pm, and boost (most points for 'lib' dir).
                    ($1 ? 50 : 25) + $_pod_score{lc($2)} :

                # Sort files by extension: Foo.pod > Foo.pm > foo.pl.
                $_->name =~ /\.(pod|pm|pl)/i ? $_pod_score{lc($1)} :

                # Otherwise score unknown (near the bottom).
                -1
            ),
            $_ ]
         }
         @$files
         #>>>
    );
    $self->_set_associated_pod( $file->full_path );
}

__PACKAGE__->meta->make_immutable;
1;
