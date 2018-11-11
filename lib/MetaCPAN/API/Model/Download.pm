package MetaCPAN::API::Model::Download;

use MetaCPAN::Moose;

use MetaCPAN::Types qw( Object );

has es => (
    is       => 'ro',
    isa      => Object,
    handles  => { _run_query => 'search', },
    required => 1,
);

__PACKAGE__->meta->make_immutable;

1;

