#!/usr/bin/env perl

use strict;
use warnings;

use MetaCPAN::Queue::Monitor;

# Show the jobs

my $monitor = MetaCPAN::Queue::Monitor->new({

  graph_title => 'Active Workers',
  graph_info => "What's happening in the Minion queue",
  fields => [ 'inactive_workers', 'active_workers' ],

});

$monitor->run();

