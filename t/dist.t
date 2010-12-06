#!/usr/bin/perl

use Data::Dump qw( dump );
use Modern::Perl;
use Test::More qw( no_plan );

require_ok( 'MetaCPAN' );
require_ok( 'MetaCPAN::Dist' );

my $cpan = MetaCPAN->new;

my $dist = $cpan->dist( 'Moose' );
isa_ok( $dist, 'MetaCPAN::Dist' );

ok ( $dist->module_rs->count, "got some modules" );
