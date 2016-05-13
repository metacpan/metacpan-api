#!/usr/bin/env perl

use strict;
use warnings;

=head2 DESCRIPTION

Simple script to start Mojo app.

    carton exec -- morbo bin/queue.pl

Get status on jobs and workers:

    sh /home/metacpan/bin/metacpan-api-carton-exec bin/queue.pl minion job -s

=cut

# for morbo
use lib 'lib';

# Start command line interface for application
require Mojolicious::Commands;
Mojolicious::Commands->start_app('MetaCPAN::Queue');
