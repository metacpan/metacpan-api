package MetaCPAN::Document::Permission;

use MetaCPAN::Moose;

use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw( ArrayRef Str );

has module => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has owner => (
    is  => 'ro',
    isa => Str,
);

has co_maintainers => (
    is  => 'ro',
    isa => ArrayRef,
);

__PACKAGE__->meta->make_immutable;
1;
