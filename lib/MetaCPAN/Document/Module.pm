package MetaCPAN::Document::Module;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Util;

has name => ( index => 'analyzed', analyzer => 'camelcase' );
has version => ( required => 0 );
has version_numified => ( isa => 'Num', lazy_build => 1, required => 1 );
has indexed => ( is => 'rw', isa => 'Bool', default => 0 );

sub _build_version_numified {
    my $self = shift;
    return 0 unless($self->version);
    return MetaCPAN::Util::numify_version( $self->version );
}

sub hide_from_pause {
    my ($self, $content) = @_;
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