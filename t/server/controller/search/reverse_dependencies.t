use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

my %tests = (
    '/search/reverse_dependencies/NonExistent' => [ 404, [], [] ],
    '/search/reverse_dependencies/Pod-Pm'      => [ 200, [], [] ],

    # just dist name
    '/search/reverse_dependencies/Multiple-Modules' => [
        200,
        [qw( Multiple-Modules-RDeps-0.11 )],
        [qw( Multiple-Modules-RDeps-2.03 Multiple-Modules-RDeps-A-2.03 )],
    ],

    # author/name-version
    '/search/reverse_dependencies/LOCAL/Multiple-Modules-1.01' => [
        200,
        [qw( Multiple-Modules-RDeps-0.11 )],
        [qw( Multiple-Modules-RDeps-2.03 Multiple-Modules-RDeps-A-2.03 )],
    ],

    # older author/name-version with different modules
    '/search/reverse_dependencies/LOCAL/Multiple-Modules-0.1' => [
        200,
        [qw( Multiple-Modules-RDeps-0.11 )],
        [
            qw( Multiple-Modules-RDeps-2.03 Multiple-Modules-RDeps-Deprecated-0.01 )
        ],
    ],
);

sub check_search_results {
    my ( $name, $res, $code, $rdeps ) = @_;
    ok( $res, $name );
    is(
        $res->header('content-type'),
        'application/json; charset=utf-8',
        'Content-type'
    );
    is( $res->code, $code, "code $code" )
        or return;

    my $json = decode_json_ok($res);
    return unless $code == 200;

    $json = $json->{hits}{hits} if $json->{hits};
    is scalar @$json, @$rdeps, 'got expected number of releases';
    is_deeply [
        sort map { join q[-], @{ $_->{_source} }{qw(distribution version)} }
            @$json
        ],
        $rdeps,
        'got expected releases';
}

test_psgi app, sub {
    my $cb = shift;

    # verify search results
    while ( my ( $k, $v ) = each %tests ) {
        my ( $code, $rdep_old, $rdep_latest ) = @$v;

        # all results
        check_search_results(
            "GET $k" => $cb->( GET $k ),
            $code, [ sort( @$rdep_old, @$rdep_latest ) ]
        );

        # only releases marked as latest
        check_search_results(
            "POST $k" => $cb->(
                POST $k,
                Content => encode_json(
                    {
                        query => { match_all => {} },
                        filter =>
                            { term => { 'release.status' => 'latest' }, },
                    }
                )
            ),
            $code,
            [ sort(@$rdep_latest) ]
        );
    }

    # test passing additional ES parameters
    {
        ok(
            my $res = $cb->(
                POST '/search/reverse_dependencies/Multiple-Modules',
                Content => encode_json(
                    { query => { match_all => {} }, size => 1 }
                )
            ),
            'POST'
        );
        my $json = decode_json_ok($res);
        is( $json->{hits}->{total},            3, 'total is 3' );
        is( scalar @{ $json->{hits}->{hits} }, 1, 'only 1 received' );
    }

    # test appending filters
    {
        ok(
            my $res = $cb->(
                POST
                    '/search/reverse_dependencies/Multiple-Modules?fields=release.distribution',
                Content => encode_json(
                    {
                        query  => { match_all => {} },
                        filter => {
                            term => {
                                'release.distribution' =>
                                    'Multiple-Modules-RDeps-A'
                            },
                        },
                    }
                )
            ),
            'POST'
        );

        my $json = decode_json_ok($res);
        is( $json->{hits}->{total}, 1, 'total is 1' );
        is( $json->{hits}->{hits}->[0]->{fields}->{distribution}->[0],
            'Multiple-Modules-RDeps-A', 'filter worked' );
    }
};

done_testing;
