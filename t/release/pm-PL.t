use strict;
use warnings;

use Test::More;
use MetaCPAN::Server::Test;

my $model = model();
my $idx   = $model->index( 'cpan' );

ok( my $pm = $idx->type( 'file' )->find( 'uncommon:sense' ),
    'find sense.pm.PL module' );

is( $pm->name, 'sense.pm.PL', 'name is correct' );

is( $pm->module->[0]->associated_pod,
    'MO/uncommon-sense-0.01/sense.pod',
    'has associated pod file'
);

done_testing;
