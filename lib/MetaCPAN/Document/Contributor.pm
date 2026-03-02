package MetaCPAN::Document::Contributor;

use MetaCPAN::Moose;

use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw( ArrayRef Str );

has distribution => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has release_author => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has release_name => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has pauseid => (
    is  => 'ro',
    isa => Str,
);

has name => (
    is  => 'ro',
    isa => Str,
);

has email => (
    is  => 'ro',
    isa => ArrayRef [Str],
);

__PACKAGE__->meta->make_immutable;
1;
