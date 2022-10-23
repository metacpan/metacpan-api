use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::TestHelpers qw( test_release );
use Test::More;

test_release( {
    name => 'weblint++-1.15',

    # FIXME: Should we be stripping this?
    distribution => 'weblint',

    author     => 'LOCAL',
    authorized => 1,
    first      => 1,
    version    => '1.15',

    # No modules.
    status => 'cpan',

    provides => [],

    tests => 1,

    extra_tests => sub {
        my ($self) = @_;

        {
            is $self->data->distribution, 'weblint',
                'distribution matches META name, but strips out ++';
        }
    },
} );

done_testing;
