use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Script::River ();
use MetaCPAN::Server::Test  qw( app GET );
use MetaCPAN::TestHelpers   qw( decode_json_ok );
use MetaCPAN::Util          qw( root_dir );
use Plack::Test             ();
use Test::More;
use URI ();

my $config = MetaCPAN::Server::Config::config();

# local json file with structure from https://github.com/metacpan/metacpan-api/issues/460
my $root = root_dir();
my $file = URI->new('t/var/river.json')->abs("file://$root/");
$config->{'river_url'} = "$file";

my $river = MetaCPAN::Script::River->new_with_options($config);
ok $river->run, 'runs and returns true';

my %expect = (
    'System-Command' => {
        total     => 92,
        immediate => 4,
        bucket    => 2,
    },
    'Text-Markdown' => {
        total     => 92,
        immediate => 56,
        bucket    => 2,
    }
);

my $test = Plack::Test->create( app() );

for my $dist ( keys %expect ) {
    my $expected = $expect{$dist};
    subtest "Check $dist" => sub {
        my $url = "/distribution/$dist";
        my $res = $test->request( GET $url );
        diag "GET $url";

        # TRAVIS 5.18
        is( $res->code, 200, "code 200" );
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        my $json = decode_json_ok($res);

        # TRAVIS 5.18
        is_deeply( $json->{river}, $expected,
            "$dist river summary roundtrip" );
    };
    last;
}

done_testing();
