#!/usr/bin/env perl

use Modern::Perl;
use Find::Lib '../lib';
use MetaCPAN;

die "Usage: perl create_index.pl index_name" if !@ARGV;

MetaCPAN->new->es->create_index(
    index   => shift @ARGV,
);
