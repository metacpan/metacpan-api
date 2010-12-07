#!/usr/bin/env perl

use Modern::Perl;
use Find::Lib '../lib';
use MetaCPAN;

die "Usage: perl delete_index.pl index_name" if !@ARGV;

MetaCPAN->new->es->delete_index(
    index   => shift @ARGV,
);
