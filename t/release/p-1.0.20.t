use Test::More;
use strict;
use warnings;

use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    {
        name         => 'P-1.0.20',
        distribution => 'P',
        author       => 'LOCAL',
        authorized   => \1,
        first        => \1,
        version      => 'v1.0.20',

        provides => [ 'P', ],

        extra_tests => sub {
            my ($self) = @_;
            my $tests = $self->data->tests;

            # Don't test the actual numbers since we copy this out of the real
            # database as a live test case.

            ok( is_hashref($tests), 'hashref of tests' );

            ok $tests->{pass} > 0, 'has passed tests';

            ok exists( $tests->{$_} ), "has '$_' results"
                for qw( pass fail na unknown );
        },
    }
);

done_testing;
