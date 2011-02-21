#!/usr/bin/perl

use Data::Dump qw( dump );
use feature 'say';
use Test::More tests => 3;

require_ok( 'MetaCPAN' );
my $cpan = MetaCPAN->new;

isa_ok( $cpan, 'MetaCPAN' );
ok( $cpan->schema, "got schema");
