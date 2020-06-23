package MetaCPAN::Document::Cover;

use MetaCPAN::Moose;

use ElasticSearchX::Model::Document;
use MetaCPAN::Types::TypeTiny qw( HashRef Str );

has distribution => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has release => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has version => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has criteria => (
    is       => 'ro',
    isa      => HashRef,
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
