use strict;
use warnings;

use MetaCPAN::TestHelpers;
use Test::More;

# Some uploads contain no usable modules.
test_release(
    {
        name       => 'No-Packages-1.1',
        author     => 'BORISNAT',
        authorized => 1,
        first      => 1,

        # Without modules it won't get marked as latest.
        status => 'cpan',

        provides => [

            # empty
        ],
        modules => {

            # empty
        },
    }
);

done_testing;
