use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

my $model = model();
my $idx   = $model->index('cpan');

ok( my $pod_pm = $idx->type('file')->find('Pod::Pm'), 'find Pod::Pm module' );

is( $pod_pm->name, 'Pm.pm', 'defined in Pm.pm' );

is(
    $pod_pm->module->[0]->associated_pod,
    'MO/Pod-Pm-0.01/lib/Pod/Pm.pod',
    'has associated pod file'
);

done_testing;
