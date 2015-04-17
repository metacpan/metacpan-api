use strict;
use warnings;

use lib 't/lib';
use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

test_psgi app, sub {
    my $cb = shift;

    # test ES script using doc['blah'] value
    {
        ok( my $res = $cb->( GET '/search/autocomplete?q=Multiple::Modu' ),
            'GET' );
        my $json = decode_json_ok($res);

        my $got
            = [ map { $_->{_source}{documentation} } @{ $json->{hits}{hits} } ];

        is_deeply $got, [ qw(
                Multiple::Modules
                Multiple::Modules::A
                Multiple::Modules::B
                Multiple::Modules::RDeps
                Multiple::Modules::Tester
                Multiple::Modules::RDeps::A
                Multiple::Modules::RDeps::Deprecated
                )
            ],
            'results are sorted by module name length'
            or diag( Test::More::explain($got) );
    }
};

done_testing;
