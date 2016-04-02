use strict;
use warnings;

use Test::More;

use MetaCPAN::Script::Runner;
use MetaCPAN::Script::Queue;

my $config = MetaCPAN::Script::Runner::build_config;
local @ARGV = ( '--dir', $config->{cpan} );

use DDP;
diag np $config;

my $queue = MetaCPAN::Script::Queue->new_with_options($config);
$queue->run;
ok('does not die');

done_testing();
