use strict;
use warnings;
use Test::More 0.88;
use Test::Builder::Tester;

# NOTE: These are just here to make sure we don't goof and accidentally
# not test a bunch of stuff.  A few simple tests should suffice.
# Test::Tester doesn't work with subtests so use Test::Builder::Tester.
# It's a bit cumbersome, but not too bad... Just run the test you want
# normally (put "test_thingy(@args)" at the top of this file and run
# perl -Ilib t/helpers.t), copy the output, and, if it looks like what you
# expected to run, paste it into a heredoc.  Then just put the test in a call
# to expect_output() like the others.  (You may need to fudge the sequence numbers
# of any top-level tests (contents of subtests should be fine).)
# You can also debug the output (or get updated output)
# by passing (no_capture => 1) to expect_output().
# As long as tests are run in a reliable order (sort keys) it should be fine.
# If you're so inclined, feel free to use the full Test::Builder::Tester API
# (or something else).  If that doesn't work we'll figure something else out.

#use MetaCPAN::Server::Test;
use lib 't/lib';
use MetaCPAN::TestHelpers;

sub chomped { chomp(my $s = $_[0]); $s }
sub expect_output {
    my (%opts) = @_;

    if( $opts{no_capture} ){
        diag("\nTEST OUTPUT {\n");
    }
    else {
        test_out(chomped($opts{out}));
        test_err(chomped($opts{err})) if $opts{err};
    }

    $opts{tests}->();

    if( $opts{no_capture} ){
        diag("\n} TEST OUTPUT\n");
    }
    else {
        test_test(
            map  { ($_ => $opts{$_}) }
            grep { exists($opts{$_}) }
                qw( title skip_out skip_err )
        );
    }
}

expect_output(out => <<TESTS,
    # Subtest: test_release helper
    ok 1 - Search successful
        # Subtest: extra_tests
        ok 1 - hooray
        1..1
    ok 2 - extra_tests
        # Subtest: expected_attributes
        ok 1 - abstract
        ok 2 - author
        ok 3 - name
        1..3
    ok 3 - expected_attributes
        # Subtest: release
        ok 1 - release author
        ok 2 - release distribution
        ok 3 - release version
        ok 4 - release version_numified
        ok 5 - release status
        ok 6 - release archive
        ok 7 - release name
        1..7
    ok 4 - release
    1..4
ok 1 - test_release helper
TESTS
    err => '        # for Moose',

    tests => sub {
        test_release(
            'DOY/Moose-0.02',
            {
                abstract => 'A standard perl distribution',
                extra_tests => sub {
                    ok(1, 'hooray');
                    diag('for ' . $_[0]->data->distribution);
                },
            },
            'test_release helper',
        );
    },

    title => 'test_release',
);


expect_output(out => <<TESTS,
    # Subtest: Distribution data for uncommon-sense
    ok 1 - Search successful
        # Subtest: extra_tests
        1..0 # SKIP No extra tests defined
    ok 2 # skip No extra tests defined
        # Subtest: expected_attributes
        not ok 1 - bugs
        ok 2 - name
        1..2
    not ok 3 - expected_attributes
        # Subtest: info
        ok 1 - name
        1..1
    ok 4 - info
    1..4
not ok 1 - Distribution data for uncommon-sense
TESTS

    tests => sub {
        test_distribution(
            'uncommon-sense',
            {
                bugs => {},
            },
        );
    },

    title => 'test_distribution with failures and default description',
    # The STDERR is a mess, and I don't really care;
    # just show me that tests can fail.
    skip_err => 1,
);


expect_output(out => <<TESTS,
    # Subtest: not found
    not ok 1 - Search successful
    not ok 2 - Search failed; cannot proceed with test: extra_tests
    not ok 3 - Search failed; cannot proceed with test: expected_attributes
    not ok 4 - Search failed; cannot proceed with test: release
    1..4
not ok 1 - not found
TESTS

    tests => sub {
        test_release(
            {
                author => 'STINKYPETE',
                name   => 'prospectus',
                extra_tests => sub {
                    ok(1, 'hooray');
                },
            },
            'not found',
        );
    },

    title => 'fail search, skip remaining tests',
    # Again, STDERR is a big mess, just show that the search fails
    # and the rest of the tests don't attempt to run.
    skip_err => 1,
);


done_testing;
