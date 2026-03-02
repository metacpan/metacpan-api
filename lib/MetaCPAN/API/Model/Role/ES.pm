package MetaCPAN::API::Model::Role::ES;

use Moose::Role;

use MetaCPAN::Types qw( Object );

has es => (
    is       => 'ro',
    isa      => Object,
    handles  => { _run_query => 'search', },
    required => 1,
);

no Moose::Role;
1;

