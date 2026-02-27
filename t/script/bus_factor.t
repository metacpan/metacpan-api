use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Script::BusFactor ();
use MetaCPAN::Server::Test      qw( app GET );
use MetaCPAN::TestHelpers       qw( decode_json_ok testdata_dir );
use Plack::Test                 ();
use Test::More;
use URI ();

my $config = MetaCPAN::Server::Config::config();

# local json file with a small subset of production data
my $file = URI->new( 'file://' . testdata_dir()->child('bus_factor.json') );
$config->{bus_factor_url} = "$file";

my $bus_factor = MetaCPAN::Script::BusFactor->new_with_options($config);
ok $bus_factor->run, 'runs and returns true';

my %expect = (
    'System-Command' => 2,
    'Text-Markdown'  => 1,
);

my $test = Plack::Test->create( app() );

for my $dist ( sort keys %expect ) {
    my $expected_bus_factor = $expect{$dist};
    subtest "Check $dist" => sub {
        my $url = "/distribution/$dist";
        my $res = $test->request( GET $url );
        note "GET $url";

        is( $res->code, 200, "code 200" );
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        my $json = decode_json_ok($res);

        is( $json->{river}{bus_factor},
            $expected_bus_factor,
            "$dist bus_factor is $expected_bus_factor" );
    };
}

done_testing();
