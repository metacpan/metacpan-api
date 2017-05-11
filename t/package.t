use strict;
use warnings;

use Test::More;
use MetaCPAN::Script::Runner;

local @ARGV = ('package');

# uses ./t/var/tmp/fakecpan/modules/02packages.details.txt
ok( MetaCPAN::Script::Runner->run, 'runs' );

done_testing();
