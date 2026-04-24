use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::TestHelpers qw( fakecpan_dir testdata_dir tmp_dir );
use MetaCPAN::TestServer  ();
use Test::More 0.96;

# Help debug inconsistent parsing failures.
use Parse::PMFile ();
local $Parse::PMFile::VERBOSE = $ENV{TEST_VERBOSE} ? 9 : 0;

# Ensure we're starting fresh
my $tmp_dir = tmp_dir();
$tmp_dir->remove_tree( { safe => 0 } );
$tmp_dir->mkpath;

my $fakecpan_dir = fakecpan_dir();

# ensure fake cpan is empty
$fakecpan_dir->remove_tree;
$fakecpan_dir = fakecpan_dir();

ok( $tmp_dir->stat, "$tmp_dir exists for testing" );

system( $^X, testdata_dir() . '/mk-cpan.pl', $fakecpan_dir ) == 0
    or BAIL_OUT "failed to build fake CPAN!\n";

my $server = MetaCPAN::TestServer->new;

$server->put_mappings;

$server->index_authors;
$server->index_mirrors;
$server->index_permissions;
$server->index_packages;
$server->index_releases;
$server->set_latest;
$server->set_first;
$server->index_cpantesters;
$server->index_favorite;
$server->index_cover;
$server->index_river;
$server->index_bus_factor;
$server->index_tickets;

$server->prepare_user_test_data;

$server->wait_for_es;

done_testing;
