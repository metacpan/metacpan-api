use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;
use Test::Routine::Util;
use lib 't/lib';

my %tests = (
    '/module'                   => 200,
    '/module/Moose'             => 200,
    '/module/DOESNEXIST'        => 404,
    '/module/DOES/Not/Exist.pm' => 404,
    '/module/DOY/Moose-0.01/lib/Moose.pm' => 200
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
        if ( $k eq '/module' ) {
            ok( $json->{hits}->{total}, 'got total count' );
        }
        elsif ( $v eq 200 ) {
            ok( $json->{name} eq 'Moose.pm', 'Moose.pm' );
        }
    }
};

run_tests(
    'module/file api output for a "normal" module',
    [map { "MetaCPAN::Tests::API::$_" } qw( Module Pod )],
    {
        package        => 'Moose',
        author         => 'DOY',
        release        => 'Moose-0.02',
        associated_pod => 'DOY/Moose-0.02/lib/some_script.pl',
        path           => 'lib/Moose.pm',
        documentation  => 'Moose',
        pod_format     => 'pod',
        pod_re         => qr/=head1 NAME\n\nMoose - abstract\n\n/,
    },
);

done_testing;
