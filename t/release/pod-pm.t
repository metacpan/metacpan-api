use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( query );
use Test::More;

my $query = query();

ok( my $pod_pm = $query->file->find_module('Pod::Pm'),
    'find Pod::Pm module' );

is( $pod_pm->{name}, 'Pm.pm', 'defined in Pm.pm' );

is(
    $pod_pm->{module}->[0]->{associated_pod},
    'MO/Pod-Pm-0.01/lib/Pod/Pm.pod',
    'has associated pod file'
);

done_testing;
