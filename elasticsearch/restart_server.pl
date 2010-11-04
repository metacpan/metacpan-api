#!/usr/bin/env perl

use Modern::Perl;
use Find::Lib '../lib';
use MetaCPAN;

my $es = MetaCPAN->new->es;

my $result = $es->restart(
#    nodes       => multi,
    delay       => '5s'        # optional
);
