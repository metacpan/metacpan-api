package MetaCPAN::Types;
use strict;
use warnings;

use Type::Library -base;
use Type::Utils qw( extends );

extends qw(
    MetaCPAN::Types::Author
    MetaCPAN::Types::Distribution
    MetaCPAN::Types::File
    MetaCPAN::Types::Internal
    MetaCPAN::Types::Release
    MetaCPAN::Types::User
    Types::Standard
    Types::Path::Tiny
    Types::URI
    Types::Common::String
);

1;
