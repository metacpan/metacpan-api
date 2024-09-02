use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Script::Runner ();
use Test::More;

local @ARGV = ('permission');

# uses ./t/var/tmp/fakecpan/modules/06perms.txt
ok( MetaCPAN::Script::Runner->run, 'runs' );

done_testing();
