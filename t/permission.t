use strict;
use warnings;

use Test::More;
use MetaCPAN::Script::Runner;

local @ARGV = ('permission');

# uses ./t/var/tmp/fakecpan/modules/06perms.txt
ok( MetaCPAN::Script::Runner->run, 'runs' );

done_testing();
