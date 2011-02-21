#!/usr/bin/env perl

use feature 'say';
use Data::Dump qw( dump );
use Find::Lib '../lib';
use MetaCPAN;

my $es = MetaCPAN->new->es;

say dump( $es->nodes_stats );
