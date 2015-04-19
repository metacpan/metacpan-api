use strict;
use warnings;

use lib 't/lib';

# Require version for subtests but let Test::Most do the ->import()
use Test::More 0.96 ();
use Test::Most;

# Don't warn about Parse::PMFile's exit()
use Test::Aggregate::Nested 0.371 ();

use CPAN::Faker 0.010;
use Config::General;
use DDP;
use File::Copy;
use MetaCPAN::Script::Author;
use MetaCPAN::Script::Latest;
use MetaCPAN::Script::Mapping;
use MetaCPAN::Script::Release;
use MetaCPAN::Script::Runner;
use MetaCPAN::Script::Tickets;
use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw( get_config );
use MetaCPAN::TestServer;
use Module::Faker 0.015 ();    # Generates META.json.
use Path::Class qw(dir file);
use Search::Elasticsearch;
use Search::Elasticsearch::TestServer;

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

my $server = MetaCPAN::TestServer->new;
my $config = get_config();
$config->{es} = $server->es_client;

$server->put_mappings;

foreach my $test_dir ( $config->{cpan}, $config->{source_base} ) {
    next unless $test_dir;
    my $dir = dir($test_dir);
    if ( -e $dir->absolute ) {
        ok( $dir->rmtree, "remove old test dir: $dir" );
    }
}

my $mod_faker = 'Module::Faker::Dist::WithPerl';
eval "require $mod_faker" or die $@;    ## no critic (StringyEval)

my $cpan = CPAN::Faker->new(
    {
        source     => 't/var/fakecpan/configs',
        dest       => $config->{cpan},
        dist_class => $mod_faker,
    }
);

ok( $cpan->make_cpan, 'make fake cpan' );

# do some changes to 06perms.txt
{
    my $perms_file = dir( $config->{cpan} )->file(qw(modules 06perms.txt));
    my $perms      = $perms_file->slurp;
    $perms =~ s/^Some,LOCAL,f$/Some,MO,f/m;
    my $fh = $perms_file->openw;
    print $fh $perms;
    close $fh;
}

# Help debug inconsistent parsing failures.
require Parse::PMFile;
local $Parse::PMFile::VERBOSE = $ENV{TEST_VERBOSE} ? 9 : 0;

local @ARGV = ( 'release', $config->{cpan}, '--children', 0 );
ok( MetaCPAN::Script::Release->new_with_options($config)->run,
    'index fakecpan' );

local @ARGV = ('latest');
ok( MetaCPAN::Script::Latest->new_with_options($config)->run, 'latest' );

my $cpan_dir = dir( 't', 'var', 'fakecpan', );

copy( $cpan_dir->file('00whois.xml'),
    file( $config->{cpan}, qw(authors 00whois.xml) ) );

copy( $cpan_dir->file('author-1.0.json'),
    file( $config->{cpan}, qw(authors id M MO MO author-1.0.json) ) );

copy( $cpan_dir->file('bugs.tsv'), file( $config->{cpan}, 'bugs.tsv' ) );

{
    local @ARGV = ('author');
    ok( MetaCPAN::Script::Author->new_with_options($config)->run,
        'index authors' );
}

ok(
    MetaCPAN::Script::Tickets->new_with_options(
        {
            %$config,
            rt_summary_url => 'file://'
                . file( $config->{cpan}, 'bugs.tsv' )->absolute,
            github_issues => 'file://'
                . dir(qw(t var fakecpan github))->absolute
                . '/%s/%s.json?per_page=100',
        }
        )->run,
    'tickets'
);

$server->wait_for_es();

subtest 'Nested tests' => sub {
    my $tests = Test::Aggregate::Nested->new(
        {
            # should we do a glob to get these (and strip out t/var)?
            dirs => [
                qw(
                    t/document
                    t/release
                    t/server
                    )
            ],
            verbose => ( $ENV{TEST_VERBOSE} ? 2 : 0 ),
        }
    );

    $tests->run;
};

done_testing;
