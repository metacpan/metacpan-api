package MetaCPAN::Document::Package;

use MetaCPAN::Moose;

use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw( Str );

has module_name => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has version => (
    is  => 'ro',
    isa => Str,
);

has file => (
    is  => 'ro',
    isa => Str,
);

__PACKAGE__->meta->make_immutable;
1;
