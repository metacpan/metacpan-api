use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Script::Runner ();
use Module::Pluggable search_dirs => ['t/lib'];
use Test::More;

subtest 'runner succeeds' => sub {
    local @ARGV = ('mockerror');

    ok( MetaCPAN::Script::Runner::run, 'succeeds' );

    is( $MetaCPAN::Script::Runner::EXIT_CODE, 0, "Exit Code '0' - No Error" );
};

subtest 'runner fails' => sub {
    local @ARGV
        = ( 'mockerror', '--error', 11, '--message', 'mock error message' );

    ok( !MetaCPAN::Script::Runner::run, 'fails as expected' );

    is( $MetaCPAN::Script::Runner::EXIT_CODE,
        11, "Exit Code '11' as expected" );
};

# Disable for the time being. There is a better way to check exit codes.
#
# subtest 'runner dies' => sub {
#     local @ARGV = ( 'mockerror', '--die', '--message', 'mock die message' );
#
#     ok( !MetaCPAN::Script::Runner::run, 'fails as expected' );
#
#     is( $MetaCPAN::Script::Runner::EXIT_CODE, 1,
#         "Exit Code '1' as expected" );
# };

subtest 'runner exits with error' => sub {
    local @ARGV = (
        'mockerror', '--handle_error', '--error', 17, '--message',
        'mock handled error message'
    );

    ok( !MetaCPAN::Script::Runner::run, 'fails as expected' );

    is( $MetaCPAN::Script::Runner::EXIT_CODE,
        17, "Exit Code '17' as expected" );
};

subtest 'runner throws exception' => sub {
    local @ARGV = (
        'mockerror', '--exception', '--error', 19, '--message',
        'mock exception message'
    );

    ok( !MetaCPAN::Script::Runner::run, 'fails as expected' );

    is( $MetaCPAN::Script::Runner::EXIT_CODE,
        19, "Exit Code '19' as expected" );
};

done_testing();
