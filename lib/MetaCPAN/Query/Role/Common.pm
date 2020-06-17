package MetaCPAN::Query::Role::Common;

use Moose::Role;

has es => ( is => 'ro', );

has index_name => ( is => 'ro', );

1;
