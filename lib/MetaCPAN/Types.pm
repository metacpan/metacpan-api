package MetaCPAN::Types;

use strict;
use warnings;

use parent 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw(
        MetaCPAN::Types::Internal
        MooseX::Types::Common::Numeric
        MooseX::Types::Common::String
        MooseX::Types::Moose
        MooseX::Types::Path::Tiny
        MooseX::Types::Structured
        MooseX::Types::URI
        )
);

1;
