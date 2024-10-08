use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::TestHelpers qw( test_release );
use MetaCPAN::Util        qw(true false);
use Test::More;

# Some uploads contain no usable modules.
test_release( {
    name       => 'No-Packages-1.1',
    author     => 'BORISNAT',
    authorized => true,
    first      => true,

    # Without modules it won't get marked as latest.
    status => 'cpan',

    provides => [

        # empty
    ],
    modules => {

        # empty
    },
} );

done_testing;
