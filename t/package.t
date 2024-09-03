use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Script::Runner ();
use Test::More;

local @ARGV = ('package');

# uses ./t/var/tmp/fakecpan/modules/02packages.details.txt
ok( MetaCPAN::Script::Runner->run, 'runs' );

done_testing();
