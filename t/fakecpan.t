use Test::More 0.96 (); # require version for subtests but let Test::Most do the ->import()
use Test::Most;
use Test::Aggregate::Nested ();
use strict;
use warnings;
use CPAN::Faker;
use Module::Faker 0.010 (); # encoding fix for newer perls
use ElasticSearch::TestServer;
use MetaCPAN::Script::Runner;
use MetaCPAN::Script::Mapping;
use MetaCPAN::Script::Release;
use MetaCPAN::Script::Author;
use MetaCPAN::Script::Tickets;
use Path::Class qw(dir file);
use File::Copy;
use Config::General;

ok( my $es = ElasticSearch->new(
        transport => 'httplite',
        servers   => '127.0.0.1:9900',
        # trace_calls => 1,
), 'got ElasticSearch object');

eval {
  $es->transport->refresh_servers;
};

ok(!$@, "Connected to the ElasticSearch test instance on 127.0.0.1:9900")
  or do {
    diag(<<EOF);
Failed to connect to the ElasticSearch test instance on 127.0.0.1:9900.
Did you start one up? See https://github.com/CPAN-API/cpan-api/wiki/Installation
for more information.
EOF

    BAIL_OUT("Test environment not set up properly");
};



my $config = MetaCPAN::Script::Runner->build_config;
$config->{es} = $es;

{
    local @ARGV = qw(mapping --delete);
    ok(
        MetaCPAN::Script::Mapping->new_with_options($config)->run,
        'put mapping'
    );
    wait_for_es();
}

if (-e dir($config->{cpan})->absolute) {
	ok(dir($config->{cpan})->rmtree, 'remove old fakepan');
}

my $cpan = CPAN::Faker->new({
  source => 't/var/fakecpan/configs',
  dest   => $config->{cpan},
});
 
ok($cpan->make_cpan, 'make fake cpan');

# do some changes to 06perms.txt
{
    my $perms_file = dir($config->{cpan})->file(qw(modules 06perms.txt));
    my $perms = $perms_file->slurp;
    $perms =~ s/^Some,LOCAL,f$/Some,MO,f/m;
    my $fh = $perms_file->openw;
    print $fh $perms;
    close $fh;
}

local @ARGV = ('release', $config->{cpan}, '--children', 0);
ok(
    MetaCPAN::Script::Release->new_with_options($config)->run,
    'index fakecpan'
);

local @ARGV = ('latest');
ok(
    MetaCPAN::Script::Latest->new_with_options($config)->run,
    'latest'
);

copy(file(qw(t var fakecpan 00whois.xml)),file($config->{cpan}, qw(authors 00whois.xml)));
copy(file(qw(t var fakecpan author-1.0.json)),file($config->{cpan}, qw(authors id M MO MO author-1.0.json)));
copy(file(qw(t var fakecpan bugs.tsv)),file($config->{cpan}, qw(bugs.tsv)));
local @ARGV = ('author', '--cpan', $config->{cpan});
ok(
    MetaCPAN::Script::Author->new_with_options($config)->run,
    'index authors'
);

ok( MetaCPAN::Script::Tickets->new_with_options(
        {   %$config,
            rt_summary_url => "file://"
                . file( $config->{cpan}, 'bugs.tsv' )->absolute,
            github_issues => "file://" . dir(qw(t var fakecpan github))->absolute . '/%s/%s.json?per_page=100',
        }
        )->run,
    'tickets'
);

wait_for_es();

sub wait_for_es {
    sleep $_[0] if $_[0];
    $es->cluster_health(
        wait_for_status => 'yellow',
        timeout         => '30s'
    );
    $es->refresh_index();
}

subtest 'Nested tests' => sub {
    my $tests = Test::Aggregate::Nested->new( {
        # should we do a glob to get these (and strip out t/var)?
        dirs    => [qw(
            t/document
            t/release
            t/script
            t/server
        )],
        verbose => 2,
    } );

    $tests->run;
};

done_testing;
