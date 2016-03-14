use Test::More;

use MetaCPAN::Queue::Helper;

my $helper = MetaCPAN::Queue::Helper->new;

ok( $helper->backend, 'backend' );

done_testing();
