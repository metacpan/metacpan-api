use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestHelpers  qw( decode_json_ok );
use Test::More;

my %expect = (
    'MetaFile-Both-1.1' => {
        criteria => {
            branch     => '12.50',
            condition  => '0.00',
            statement  => '63.64',
            subroutine => '71.43',
            total      => '46.51',
        },
        distribution => 'MetaFile-Both',
        release      => 'MetaFile-Both-1.1',
        url     => 'http://cpancover.com/latest/MetaFile-Both-1.1/index.html',
        version => '1.1',
    },
    'Pod-With-Generator-1' => {
        criteria => {
            branch     => '78.95',
            condition  => '46.67',
            statement  => '95.06',
            subroutine => '100.00',
            total      => '86.58',
        },
        distribution => 'Pod-With-Generator',
        release      => 'Pod-With-Generator-1',
        url => 'http://cpancover.com/latest/Pod-With-Generator-1/index.html',
        version => '1',
    },
);

my $test = Plack::Test->create( app() );

for my $release ( keys %expect ) {
    my $expected = $expect{$release};
    subtest "Check $release" => sub {
        my $url = "/cover/$release";
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
        is_deeply( $json, $expected, "$release cover summary roundtrip" );
    };
}

done_testing();
