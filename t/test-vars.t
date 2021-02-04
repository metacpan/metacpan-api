use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Vars import => [qw( vars_ok )];

vars_ok('MetaCPAN::Server');

done_testing();
