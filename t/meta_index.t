#!/usr/bin/perl

use Data::Dump qw( dump );
use Modern::Perl;
use Test::More qw( no_plan );

require_ok('MetaCPAN::Extract::MetaIndex');

my $meta = MetaCPAN::Extract::MetaIndex->new;

isa_ok( $meta, 'MetaCPAN::Extract::MetaIndex');
ok( $meta->schema->storage->dbh, "got dbh");
isa_ok( $meta->schema->storage->dbh, 'DBI::db');

ok( -e $meta->db_file, 'database exists at: ' . $meta->db_file );
ok( $meta->dsn, "got dsn: " . $meta->dsn );

my $distro = $meta->schema->resultset( 'MetaCPAN::Extract::Meta::Schema::Result::Module' )
    ->find( { name => 'HTML::Restrict' } );

diag( $distro->name );

my %cols = $distro->get_columns;
diag( dump \%cols );
