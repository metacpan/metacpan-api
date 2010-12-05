#!/usr/bin/perl

use Data::Dump qw( dump );
use Modern::Perl;
use Test::More qw( no_plan );

require_ok( 'MetaCPAN::Extract' );
require_ok( 'MetaCPAN::Extract::Dist' );

my $icpan = MetaCPAN::Extract->new;

my $dist = $icpan->dist( 'Moose' );
isa_ok( $dist, 'MetaCPAN::Extract::Dist' );

ok ( $dist->modules->count, "got some modules" );
