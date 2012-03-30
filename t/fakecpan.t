use Test::Most;
use Test::Aggregate;
use strict;
use warnings;
use CPAN::Faker;
use ElasticSearch::TestServer;
use MetaCPAN::Script::Runner;
use MetaCPAN::Script::Mapping;
use MetaCPAN::Script::Release;
use MetaCPAN::Script::Author;
use Path::Class qw(dir file);
use File::Copy;
use Config::General;

ok( my $es = ElasticSearch->new(
        transport => 'httplite',
        servers   => '127.0.0.1:9900',
        # trace_calls => 1,
    ),
    'connect to es'
);

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
local @ARGV = ('author', '--cpan', $config->{cpan});
ok(
    MetaCPAN::Script::Author->new_with_options($config)->run,
    'index authors'
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

my $tests = Test::Aggregate->new( {
    dirs    => [qw(t/release t/server)],
    verbose => 2,
} );
$tests->run;
