use strict;
use warnings;
use lib 't/lib';

use CPAN::Faker 0.010 ();
use Devel::Confess;
use MetaCPAN::Script::Tickets ();
use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw(
    fakecpan_configs_dir
    fakecpan_dir
    get_config
    tmp_dir
);
use MetaCPAN::TestServer ();
use Module::Faker 0.015 ();    # Generates META.json.
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

my $mod_faker = 'Module::Faker::Dist::WithPerl';
eval "require $mod_faker" or die $@;    ## no critic (StringyEval)

my $fakecpan_dir = fakecpan_dir();
$fakecpan_dir->remove_tree;
$fakecpan_dir = fakecpan_dir();         # recreate dir

my $fakecpan_configs = fakecpan_configs_dir();

my $cpan = CPAN::Faker->new(
    {
        source     => $fakecpan_configs->child('configs')->stringify,
        dest       => $fakecpan_dir->stringify,
        dist_class => $mod_faker,
    }
);

ok( $cpan->make_cpan, 'make fake cpan' );
$fakecpan_dir->child('authors')->mkpath;
$fakecpan_dir->child('indices')->mkpath;

# make some changes to 06perms.txt
{
    my $perms_file = $fakecpan_dir->child('modules')->child('06perms.txt');
    my $perms      = $perms_file->slurp;
    $perms =~ s/^Some,LOCAL,f$/Some,MO,f/m;
    my $fh = $perms_file->openw;
    print $fh $perms;

    # Temporary hack.  Remove after DarkPAN 06perms generation is fixed.
    print $fh 'CPAN::Test::Dummy::Perl5::VersionBump,MIYAGAWA,f', "\n";
    print $fh 'CPAN::Test::Dummy::Perl5::VersionBump,OALDERS,c',  "\n";

    close $fh;
}

# Help debug inconsistent parsing failures.
use Parse::PMFile ();
local $Parse::PMFile::VERBOSE = $ENV{TEST_VERBOSE} ? 9 : 0;

my $src_dir = $fakecpan_configs;

$src_dir->child('00whois.xml')
    ->copy( $fakecpan_dir->child(qw(authors 00whois.xml)) );

$src_dir->child('author-1.0.json')
    ->copy( $fakecpan_dir->child(qw(authors id M MO MO author-1.0.json)) );

$src_dir->child('bugs.tsv')->copy( $fakecpan_dir->child('bugs.tsv') );

$src_dir->child('mirrors.json')
    ->copy( $fakecpan_dir->child(qw(indices mirrors.json)) );

$server->index_permissions;
$server->index_packages;
$server->index_releases;
$server->set_latest;
$server->set_first;
$server->index_authors;
$server->prepare_user_test_data;
$server->index_cpantesters;
$server->index_mirrors;
$server->index_favorite;
$server->index_cover;

ok(
    MetaCPAN::Script::Tickets->new_with_options(
        {
            %{$config},
            rt_summary_url => uri(
                scheme => 'file',
                path => $fakecpan_dir->child('bugs.tsv')->absolute->stringify,
            ),
            github_issues => uri(
                scheme => 'file',
                path   => $fakecpan_dir->child('github')->absolute->stringify
                    . '/%s/%s.json?per_page=100'
            ),
        }
    )->run,
    'tickets'
);

$server->wait_for_es();

done_testing;
