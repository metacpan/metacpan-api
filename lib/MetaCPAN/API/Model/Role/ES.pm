package MetaCPAN::API::Model::Role::ES;

use Moose::Role;

use Types::Standard qw( Object );

has es => (
    is       => 'ro',
    isa      => Object,
    handles  => { _run_query => 'search', },
    required => 1,
);

no Moose::Role;
1;

