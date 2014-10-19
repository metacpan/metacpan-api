package MetaCPAN::Document::Permission;

use strict;
use warnings;

use Moose;

use ElasticSearchX::Model::Document;
use MooseX::StrictConstructor;

has module => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has owner => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
);

has co_maintainers => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 0,
);

__PACKAGE__->meta->make_immutable;
1;
