use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my %tests = (
    '/reverse_dependencies/Multiple-Modules' => 200,
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v, "code $v" );
        is( $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );
        $json = $json->{hits}{hits} if $json->{hits};
        is scalar @$json, 2, 'got 2 releases';
        is_deeply
            [ sort map { $_->{_source}{distribution} } @$json ],
            [ sort qw(Multiple-Modules-RDeps Multiple-Modules-RDeps-A) ],
            'got 2 releases';
    }
};

done_testing;
