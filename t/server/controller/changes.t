use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my @tests = (
    # TODO: w/ no arg?
    [ '/changes/File-Changes'    => 200 ],
# TODO: '/changes/LOCAL/File-Changes-1.0'        => 200
# TODO: '/changes/File-Changes-News'             => 200
# TODO: '/changes/LOCAL/File-Changes-News-11.22' => 200
    [ '/changes/NOEXISTY'        => 404 ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ($k, $v) = @{ $test };
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v, "code $v" );
        is( $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );

        next unless $res->code == 200;

#        if ( $k eq '/distribution' ) {
#            ok( $json->{hits}->{total}, 'got total count' );
#        }

        is $json->{name}, 'Changes', 'got file named Changes';
        is $json->{distribution}, 'File-Changes', 'got expected dist';
        like $json->{content},
            qr/^Revision history for Changes.+^  - Initial Release/sm,
            'file content';
    }
};

done_testing;
