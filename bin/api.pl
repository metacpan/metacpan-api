#!/usr/bin/env perl

use strict;
use warnings;

=head2 DESCRIPTION

This is the API web server interface.

    # On vagrant VM
    ./bin/run morbo bin/api.pl

To run the api web server, run the following on one of the servers:

    # Run the daemon on a local port (tunnel to display on your browser)
    ./bin/run bin/api.pl daemon

Start Minion worker on vagrant:

    cd /home/vagrant/metacpan-api
    ./bin/run bin/api.pl minion worker

Get status on jobs and workers.

On production:

    sh /home/metacpan/bin/metacpan-api-carton-exec bin/api.pl minion job -s

On vagrant:

    cd /home/vagrant/metacpan-api
    ./bin/run bin/api.pl minion job -s

=cut

use lib 'lib';

# Start command line interface for application
require Mojolicious::Commands;
Mojolicious::Commands->start_app('MetaCPAN::API');
