use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

test_psgi app, sub {
    my $cb = shift;

    # test ES script using doc['blah'] value
    {
        ok( my $res = $cb->( GET '/search/autocomplete?q=Multiple::Modu' ),
            'GET' );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );

        my $got = [ map { $_->{fields}{documentation} }
                @{ $json->{hits}{hits} } ];

        is_deeply $got, [
            qw(
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
