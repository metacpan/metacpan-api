use Mojo::Base -strict;
use lib 't/lib';

use Test::More;
use Test::Mojo;
use Mojo::JSON qw(true false);

use MetaCPAN::Model::Search ();
use MetaCPAN::TestServer    ();
my $server = MetaCPAN::TestServer->new;

my $t = Test::Mojo->new(
    'MetaCPAN::API' => {
        es     => $server->es_client,
        secret => 'just a test',
    }
);

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

for my $release ( keys %expect ) {
    my $expected = $expect{$release};
    subtest "Check $release" => sub {

        $t->get_ok("/v1/cover/$release")->status_is(200)->json_is($expected)
            ->or( sub { diag $t->tx->res->dom } );

    };
}
done_testing;
