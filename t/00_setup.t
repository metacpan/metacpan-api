use strict;
use warnings;

use lib 't/lib';

use CPAN::Faker 0.010;
use Devel::Confess;
use File::Copy qw( copy );
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
use Path::Class qw(dir file);
use Test::More 0.96;
use URI::FromHash qw( uri );

# Ensure we're starting fresh
my $tmp_dir = tmp_dir();
$tmp_dir->rmtree;
$tmp_dir->mkpath;

ok( $tmp_dir->stat, "$tmp_dir exists for testing" );

my $server = MetaCPAN::TestServer->new;
$server->setup;

my $config = get_config();
$config->{es} = $server->es_client;

my $mod_faker = 'Module::Faker::Dist::WithPerl';
eval "require $mod_faker" or die $@;    ## no critic (StringyEval)

my $fakecpan_dir = fakecpan_dir();
$fakecpan_dir->rmtree;
$fakecpan_dir = fakecpan_dir();         # recreate dir

my $fakecpan_configs = fakecpan_configs_dir();

my $cpan = CPAN::Faker->new(
    {
        source     => $fakecpan_configs->subdir('configs')->stringify,
        dest       => $fakecpan_dir->stringify,
        dist_class => $mod_faker,
    }
);

ok( $cpan->make_cpan, 'make fake cpan' );
$fakecpan_dir->subdir('authors')->mkpath;

# do some changes to 06perms.txt
{
    my $perms_file = $fakecpan_dir->subdir('modules')->file('06perms.txt');
    my $perms      = $perms_file->slurp;
    $perms =~ s/^Some,LOCAL,f$/Some,MO,f/m;
    my $fh = $perms_file->openw;
    print $fh $perms;
    close $fh;
}

# Help debug inconsistent parsing failures.
require Parse::PMFile;
local $Parse::PMFile::VERBOSE = $ENV{TEST_VERBOSE} ? 9 : 0;

my $src_dir = $fakecpan_configs;

$src_dir->file('00whois.xml')
    ->copy_to( $fakecpan_dir->file(qw(authors 00whois.xml)) );

copy( $src_dir->file('author-1.0.json'),
    $fakecpan_dir->file(qw(authors id M MO MO author-1.0.json)) );

copy( $src_dir->file('bugs.tsv'), $fakecpan_dir->file('bugs.tsv') );

$server->index_releases;
$server->set_latest;
$server->set_first;
$server->index_authors;
$server->prepare_user_test_data;
$server->index_cpantesters;

ok(
    MetaCPAN::Script::Tickets->new_with_options(
        {
            rt_summary_url => uri(
                scheme => 'file',
                path => $fakecpan_dir->file('bugs.tsv')->absolute->stringify,
            ),
            github_issues => uri(
                scheme => 'file',
                path   => $fakecpan_dir->subdir('github')->absolute->stringify
                    . '/%s/%s.json?per_page=100'
            ),
        }
        )->run,
    'tickets'
);

$server->wait_for_es();

done_testing;
