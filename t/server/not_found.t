use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

my @tests = (
    [ '/release/File-Changes'           => 200 ],
    [ '/release/No-Dist-Here'           => 404, qr{No-Dist-Here} ],
    [ '/changes/LOCAL/File-Changes-2.0' => 200 ],
    [ '/changes/LOCAL/File-Changes-2'   => 404, qr{LOCAL/File-Changes-2} ],
    [ '/file/LOCAL/File-Changes-2.0/Changes' => 200 ],
    [
        '/file/LOCAL/File-Changes-2.0/NoChanges' => 404,
        qr{LOCAL/File-Changes-2\.0/NoChanges}
    ],
    [ '/root.file' => 404 ],
    [ '/fakedoctype/andaction'                 => 404 ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ( $path, $code, $message ) = @{$test};
        ok( my $res = $cb->( GET $path), "GET $path" );
        is( $res->code, $code, "code $code" );

        # 404 should still be json
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );

        next unless $res->code == 404;

        is( $json->{message}, "Not found", '404 message as expected' );
        is( $json->{code},    $code,       'code as expected' );
    }
};

done_testing;
