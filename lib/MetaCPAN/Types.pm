package MetaCPAN::Types;

use strict;
use warnings;

use parent 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from( qw(
    MetaCPAN::Types::Internal
) );

1;
