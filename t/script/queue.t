use strict;
use warnings;
use lib 't/lib';

use Test::More;

use MetaCPAN::Script::Runner ();
use MetaCPAN::Script::Queue  ();

my $config = MetaCPAN::Script::Runner::build_config;
local @ARGV = ( '--dir', $config->{cpan} );

my $queue = MetaCPAN::Script::Queue->new_with_options($config);
$queue->run;

is( $queue->stats->{inactive_jobs},
    54, '54 files added to queue for indexing' );

done_testing();
