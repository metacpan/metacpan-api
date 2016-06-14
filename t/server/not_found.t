use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

my @tests = (
    [ '/changes/LOCAL/File-Changes-2'          => 404 ],
    [ '/changes/LOCAL/File-Changes-2.0'        => 200 ],
    [ '/fakedoctype/andaction'                 => 404 ],
    [ '/file/LOCAL/File-Changes-2.0/Changes'   => 200 ],
    [ '/file/LOCAL/File-Changes-2.0/NoChanges' => 404 ],
    [ '/release/File-Changes'                  => 200 ],
    [ '/release/No-Dist-Here'                  => 404 ],
    [ '/root.file'                             => 404 ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ( $path, $code ) = @{$test};

        ok( my $res = $cb->( GET $path), "GET $path" );
        is( $res->code, $code, "code $code" );

        # 404 should still be json
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        my $json = decode_json_ok($res);

        next unless $res->code == 404;

        is( $json->{message}, 'Not found', '404 message as expected' );
        is( $json->{code},    $code,       'code as expected' );
    }
};

done_testing;
