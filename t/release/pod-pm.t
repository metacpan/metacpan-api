use Test::More;
use strict;
use warnings;

use MetaCPAN::Model;

my $model   = MetaCPAN::Model->new( es => ':9900' );
my $idx     = $model->index('cpan');

ok(my $pod_pm = $idx->type('file')->find('Pod::Pm'), 'find Pod::Pm module');

is($pod_pm->name, 'Pm.pm', 'defined in Pm.pm');

is($pod_pm->module->[0]->associated_pod, 'MO/Pod-Pm-0.01/lib/Pod/Pm.pod', 'has associated pod file');

done_testing;