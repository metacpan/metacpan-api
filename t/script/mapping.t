use strict;
use warnings;
use lib 't/lib';

use Test::More;

use MetaCPAN::Script::Runner qw(build_config);
use MetaCPAN::Script::Mapping;

my $config = MetaCPAN::Script::Runner::build_config;

subtest 'mapping verification succeeds' => sub {
    local @ARGV = ( 'mapping', '--verify' );
    my $mapping = MetaCPAN::Script::Mapping->new_with_options($config);

    ok( $mapping->run, "verification succeeds" );
    is( $mapping->exit_code, 0, "Exit Code '0' - No Error" );
};

done_testing();
