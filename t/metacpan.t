#!/usr/bin/perl

use Data::Dump qw( dump );
use feature 'say';
use Test::More qw( no_plan );

require_ok( 'MetaCPAN' );
require_ok( 'MetaCPAN::Script::Dist' );

my $extract = MetaCPAN->new;
ok( $extract, "got an extract object" );

my $file = $extract->open_pkg_index;
isa_ok( $file, 'IO::File');

my $index = $extract->pkg_index;
my $modules = keys %{ $index };
cmp_ok( $modules , '>', '75000', "have $modules modules in index");

ok ( $extract->module_rs, "got module resultset" );

if ( $extract->module_rs->search({})->count == 0 ) {
    diag("am building metadata rows");
    ok( $extract->populate, "can populate db");
}


