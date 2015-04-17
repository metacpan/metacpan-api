package MetaCPAN::Document::Author::Profile;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document;

with 'ElasticSearchX::Model::Document::EmbeddedRole';

use MetaCPAN::Util;

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has id => (
    is       => 'ro',
    isa      => 'Str',
    analyzer => ['simple'],
);

__PACKAGE__->meta->make_immutable;
