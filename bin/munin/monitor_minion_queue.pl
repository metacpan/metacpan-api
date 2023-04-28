#!/usr/bin/env perl

use strict;
use warnings;

# Munin runs this as metacpan user, but with root's env
# it's only for production so path is hard coded

my $config_mode = 0;
$config_mode = 1 if $ARGV[0] && $ARGV[0] eq 'config';

if ($config_mode) {

    # Dump this (though we supported dynamic below) so it's faster
    print <<'EOF';
graph_title Minion Queue stats
graph_vlabel count
graph_category metacpan_api
graph_info What's happening in the Minion queue
workers_inactive.label Inactive workers
workers_active.label Active workers
jobs_inactive.label Inactive jobs
jobs_active.label Active jobs
jobs_failed.label Failed jobs
jobs_finished.label Finished jobs
EOF

    exit;
}

# Get the stats
my $stats_report
    = `/home/metacpan/bin/metacpan-api-carton-exec bin/queue.pl minion job -s`;

my @lines = split( "\n", $stats_report );

for my $line (@lines) {
    my ( $label, $num ) = split ':', $line;

    $num =~ s/\D//g;

    my $key = lc($label);    # Was 'Inactive jobs'

    # Swap type and status around so idle_jobs becomes jobs_idle
    $key =~ s/(\w+)\s+(\w+)/$2_$1/g;

    if ($config_mode) {

        # config
        print "${key}.label $label\n";

    }
    else {
        # results
        print "${key}.value $num\n" if $num;
    }

}
