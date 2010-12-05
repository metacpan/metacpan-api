#!/usr/bin/perl

use Data::Dump qw( dump );
use Modern::Perl;
use Test::More tests => 2;

require_ok( 'MetaCPAN::Extract' );
my $cpan = MetaCPAN::Extract->new;

isa_ok( $cpan, 'MetaCPAN::Extract' );
