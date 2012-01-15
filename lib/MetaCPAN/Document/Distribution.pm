package MetaCPAN::Document::Distribution;

use Moose;
use ElasticSearchX::Model::Document;
use namespace::autoclean;

has id   => (is => 'ro', id => ['name']);
has name => (is => 'ro', required => 1);

__PACKAGE__->meta->make_immutable;

1;
