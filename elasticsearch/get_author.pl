#!/usr/bin/env perl

use feature 'say';
use Data::Dump qw( dump );
use Find::Lib '../lib';
use MetaCPAN;

die "Usage: perl get_author.pl PAUSEID" if !@ARGV;

say dump( MetaCPAN->new->es->get(
    index => 'cpan',
    type => 'author',
    id   => shift @ARGV,
) );

