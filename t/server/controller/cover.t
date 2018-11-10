use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestHelpers qw( decode_json_ok );
use Test::More;

my %expect = (
    'Devel-GoFaster-0.000' => {
        criteria => {
            branch     => '12.50',
            condition  => '0.00',
            statement  => '63.64',
            subroutine => '71.43',
            total      => '46.51',
        },
        distribution => 'Devel-GoFaster',
        release      => 'Devel-GoFaster-0.000',
        url => 'http://cpancover.com/latest/Devel-GoFaster-0.000/index.html',
        version => '0.000',
    },
    'Try-Tiny-0.27' => {
        criteria => {
            branch     => '78.95',
            condition  => '46.67',
            statement  => '95.06',
            subroutine => '100.00',
            total      => '86.58',
        },
        distribution => 'Try-Tiny',
        release      => 'Try-Tiny-0.27',
        url     => 'http://cpancover.com/latest/Try-Tiny-0.27/index.html',
        version => '0.27',
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
