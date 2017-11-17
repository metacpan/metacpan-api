package MetaCPAN::Query::Role::Common;

use Moose::Role;
use MetaCPAN::Types qw( Str );

has es => ( is => 'ro', );

has index_name => ( is => 'ro', );

1;
