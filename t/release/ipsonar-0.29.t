use Test::More;
use strict;
use warnings;

use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    {
        name         => 'IPsonar-0.29',
        distribution => 'IPsonar',

        author     => 'LOCAL',
        authorized => 1,
        first      => 1,

        # META file says ''.
        version => '',

        # Don't test the actual numbers since we copy this out of the real
        # database as a live test case.

        # This is kind of a SKIP.  This may be an actual bug which we want to
        # investigate later.
        #tests => undef,
    }
);

done_testing;
