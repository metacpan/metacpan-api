use Test::Most;
use Test::Aggregate;
use strict;
use warnings;
use CPAN::Faker;
use ElasticSearch::TestServer;
use MetaCPAN::Script::Runner;
use MetaCPAN::Script::Mapping;
use MetaCPAN::Script::Release;
use Path::Class qw(dir);

ok(my $es = ElasticSearch::TestServer->new(
      instances   => 1,
      transport   => 'http',
      ip          => '127.0.0.1',
      port        => '9900',
), 'connect to es');

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

ok(dir($config->{cpan})->rmtree, 'remove old fakecpan'); 

my $cpan = CPAN::Faker->new({
  source => 't/var/fakecpan/configs',
  dest   => $config->{cpan},
});
 
ok($cpan->make_cpan, 'make fake cpan');

local @ARGV = ('release', $config->{cpan}, '--children', 0);
ok(
    MetaCPAN::Script::Release->new_with_options($config)->run,
    'index fakecpan'
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
    dirs    => 't/fakecpan',
    verbose => 2,
} );

$tests->run;