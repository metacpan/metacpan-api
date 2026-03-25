use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS       qw( decode_json );
use MetaCPAN::Server::Test qw( app GET test_psgi );
use Test::More;

test_psgi app, sub {
    my $cb = shift;

    subtest 'bad query with unrecognized field-like colons' => sub {
        my $res = $cb->( GET '/search/web?q=disstribution:HTML:Restrict' );
        ok( $res, 'request completed' );
        is( $res->code, 400, 'returns 400 for bad query' );

        my $content = eval { decode_json( $res->content ) };
        ok( $content, 'response is valid JSON' );
        like(
            $content->{message},
            qr/Invalid search query/,
            'error message is helpful'
        );
    };

    subtest 'bad query on /search/first returns 400' => sub {
        my $res = $cb->( GET '/search/first?q=disstribution:HTML:Restrict' );
        ok( $res, 'request completed' );
        is( $res->code, 400, 'returns 400 for bad query' );

        my $content = eval { decode_json( $res->content ) };
        ok( $content, 'response is valid JSON' );
        like(
            $content->{message},
            qr/Invalid search query/,
            'error message is helpful'
        );
    };

    subtest 'valid search still works' => sub {
        my $res = $cb->( GET '/search/web?q=Foo' );
        ok( $res, 'request completed' );
        is( $res->code, 200, 'returns 200' );

        my $content = eval { decode_json( $res->content ) };
        ok( $content,                   'response is valid JSON' );
        ok( exists $content->{results}, 'has results key' );
    };
};

done_testing;
