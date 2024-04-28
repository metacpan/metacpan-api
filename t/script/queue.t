use strict;
use warnings;

use MetaCPAN::Script::Queue  ();
use MetaCPAN::Server::Config ();
use Test::More;

my $config = MetaCPAN::Server::Config::config();
local @ARGV = ( '--dir', $config->{cpan} );

my $queue = MetaCPAN::Script::Queue->new_with_options($config);
$queue->run;

is( $queue->stats->{inactive_jobs},
    54, '54 files added to queue for indexing' );

done_testing();
