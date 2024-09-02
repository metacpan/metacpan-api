use Mojo::Base -strict;

use lib 't/lib';

use MetaCPAN::TestServer ();
use Test::More;
use Test::Mojo ();

my $server = MetaCPAN::TestServer->new;

my $t = Test::Mojo->new(
    'MetaCPAN::API' => {
        es     => $server->es_client,
        secret => 'just a test',
    }
);

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

for my $release ( keys %expect ) {
    my $expected = $expect{$release};
    subtest "Check $release" => sub {

        $t->get_ok("/v1/cover/$release")->status_is(200)->json_is($expected)
            ->or( sub { diag $t->tx->res->dom } );

    };
}
done_testing;
