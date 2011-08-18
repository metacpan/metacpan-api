package MetaCPAN::Document::Author::Profile;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Util;

has name => ( is => 'ro', required => 1, isa => 'Str' );
has id => ( is => 'ro', isa => 'Str', analyzer => ['simple'] );

__PACKAGE__->meta->make_immutable;
