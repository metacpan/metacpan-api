use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::TestHelpers qw( fakecpan_dir get_config testdata_dir tmp_dir );
use MetaCPAN::TestServer  ();
use Test::More 0.96;

# Ensure we're starting fresh
my $tmp_dir = tmp_dir();
$tmp_dir->remove_tree( { safe => 0 } );
$tmp_dir->mkpath;

ok( $tmp_dir->stat, "$tmp_dir exists for testing" );

my $server = MetaCPAN::TestServer->new;
$server->setup;

my $config = get_config();
$config->{es} = $server->es_client;

my $fakecpan_dir = fakecpan_dir();
$fakecpan_dir->remove_tree;
$fakecpan_dir = fakecpan_dir();    # recreate dir

my $testdata_dir = testdata_dir();

system( $^X, "$testdata_dir/mk-cpan.pl", $fakecpan_dir ) == 0
    or BAIL_OUT "failed to build fake CPAN!\n";

# Help debug inconsistent parsing failures.
use Parse::PMFile ();
local $Parse::PMFile::VERBOSE = $ENV{TEST_VERBOSE} ? 9 : 0;

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
