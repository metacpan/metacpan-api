use strict;
use warnings;
use lib 't/lib';

use Devel::Confess;
use MetaCPAN::Script::Tickets ();
use MetaCPAN::TestHelpers qw( fakecpan_dir get_config testdata_dir tmp_dir );
use MetaCPAN::TestServer  ();
use Test::More 0.96;
use URI::FromHash qw( uri );

BEGIN {
  # We test parsing bad YAML.  This attempt emits a noisy warning which is not
  # helpful in test output, so we'll suppress it here.
    $SIG{__WARN__} = sub {
        my $msg = shift;
        return if $msg =~ m{found a duplicate key};
        warn $msg;
    };
}

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
$server->prepare_user_test_data;

ok(
    MetaCPAN::Script::Tickets->new_with_options( {
        %{$config},
        rt_summary_url => uri(
            scheme => 'file',
            path   => $testdata_dir->child('bugs.tsv')->absolute->stringify,
        ),
    } )->run,
    'tickets'
);

$server->wait_for_es();

done_testing;
