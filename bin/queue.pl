#!/usr/bin/env perl

use strict;
use warnings;

=head2 DESCRIPTION

Start Minion worker on vagrant:

    cd /home/vagrant/metacpan-api
    ./bin/run bin/queue.pl minion worker

Get status on jobs and workers.

On production:

    sh /home/metacpan/bin/metacpan-api-carton-exec bin/queue.pl minion job -s

On vagrant:

    cd /home/vagrant/metacpan-api
    ./bin/run bin/queue.pl minion job -s

=cut

# For vagrant
use lib 'lib';

# Start command line interface for application
require Mojolicious::Commands;
Mojolicious::Commands->start_app('MetaCPAN::Admin');
