use Test::More;
use strict;
use warnings;
use MetaCPAN::Util;

is(MetaCPAN::Util::numify_version(1), 1.000);
is(MetaCPAN::Util::numify_version('010'), 10.000);
is(MetaCPAN::Util::numify_version('v2.1.1'), 2.001001);
is(MetaCPAN::Util::numify_version(undef), 0.000);
is(MetaCPAN::Util::numify_version('LATEST'), 0.000);

done_testing;