use strict;
use warnings;

use MetaCPAN::Queue::Helper;
use Test::More;

my $helper = MetaCPAN::Queue::Helper->new;

ok( $helper->backend, 'backend' );

done_testing();
