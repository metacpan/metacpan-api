package MetaCPAN::Document::Author::Profile;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Util;

has name => ( isa => 'Str' );
has id => ( isa => 'Str', analyzer => ['simple'] );

__PACKAGE__->meta->make_immutable;
