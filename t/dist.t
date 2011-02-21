#!/usr/bin/perl

use Data::Dump qw( dump );
use feature 'say';
use Test::More qw( no_plan );

require_ok( 'MetaCPAN' );
require_ok( 'MetaCPAN::Script::Dist' );

my $cpan = MetaCPAN->new;

my $dist = $cpan->dist( 'Moose' );
isa_ok( $dist, 'MetaCPAN::Dist' );
