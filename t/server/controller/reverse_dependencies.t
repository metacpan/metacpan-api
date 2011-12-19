use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my %tests = (
    '/reverse_dependencies/NonExistent'      => [ 404 ],
    '/reverse_dependencies/Pod-Pm'           => [ 200, [] ],

    '/reverse_dependencies/Multiple-Modules' => [ 200,
            [ sort qw(Multiple-Modules-RDeps Multiple-Modules-RDeps-A) ] ],
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        my ($code, $rdeps) = @$v;

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
};

done_testing;
