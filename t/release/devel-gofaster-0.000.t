use strict;
use warnings;

use MetaCPAN::TestHelpers;
use Test::More;

test_release(
    {
        name         => 'Devel-GoFaster-0.000',
        distribution => 'Devel-GoFaster',
        author       => 'LOCAL',
        authorized   => 1,
        first        => 1,
        version      => '0.000',

        provides => [ 'Devel::GoFaster', ],

        # Don't test the actual numbers since we copy this out of the real
        # database as a live test case.
        tests => 1,
    }
);

done_testing;
