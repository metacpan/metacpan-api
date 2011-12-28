use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my %tests = (
    '/search/reverse_dependencies/NonExistent' => [404],
    '/search/reverse_dependencies/Pod-Pm'      => [ 200, [] ],

    '/search/reverse_dependencies/Multiple-Modules' =>
        [ 200, [ sort qw(Multiple-Modules-RDeps Multiple-Modules-RDeps-A) ] ],

    '/search/reverse_dependencies/LOCAL/Multiple-Modules-1.01' =>
        [ 200, [ sort qw(Multiple-Modules-RDeps Multiple-Modules-RDeps-A) ] ],

    '/search/reverse_dependencies/LOCAL/Multiple-Modules-0.1' => [
        200,
        [ sort qw(Multiple-Modules-RDeps Multiple-Modules-RDeps-Deprecated) ]
    ],
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        my ( $code, $rdeps ) = @$v;

        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $code, "code $code" );
        is( $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );
        next unless $code == 200;

        $json = $json->{hits}{hits} if $json->{hits};
        is scalar @$json, @$rdeps, 'got expected number of releases';
        is_deeply
            [ sort map { $_->{_source}{distribution} } @$json ],
            $rdeps,
            'got expected releases';
    }
    {
        ok( my $res = $cb->(
                POST "/search/reverse_dependencies/Multiple-Modules",
                Content => encode_json(
                    { query => { match_all => {} }, size => 1 }
                )
            ),
            "POST"
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );
        is( $json->{hits}->{total},            2, 'total is 3' );
        is( scalar @{ $json->{hits}->{hits} }, 1, 'only 1 received' );
    }

    {
        ok( my $res = $cb->(
                POST
                    "/search/reverse_dependencies/Multiple-Modules?fields=release.distribution",
                Content => encode_json(
                    {   query  => { match_all => {} },
                        filter => {
                            term => {
                                'release.distribution' =>
                                    'Multiple-Modules-RDeps-A'
                            },
                        },
                    }
                )
            ),
            "POST"
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );
        is( $json->{hits}->{total}, 1, 'total is 1' );
        is( $json->{hits}->{hits}->[0]->{fields}->{distribution},
            'Multiple-Modules-RDeps-A', 'filter worked' );
    }
};

done_testing;
