use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my @tests = (
    # TODO: w/ no arg?
    [ '/changes/File-Changes'           => 200,
        Changes => qr/^Revision history for Changes\n\n2\.0.+1\.0.+/sm, ],
    [ '/changes/LOCAL/File-Changes-2.0' => 200,
        Changes => qr/^Revision history for Changes\n\n2\.0.+1\.0.+/sm, ],
    [ '/changes/LOCAL/File-Changes-1.0' => 200,
        Changes => qr/^Revision history for Changes\n\n1\.0.+/sm, ],
    [ '/changes/File-Changes-News'             => 200,
        NEWS    => qr/^F\nR\nE\nE\nF\nO\nR\nM\n/, ],
    [ '/changes/LOCAL/File-Changes-News-11.22' => 200,
        NEWS    => qr/^F\nR\nE\nE\nF\nO\nR\nM\n/, ],
    [ '/changes/NOEXISTY'        => 404 ],
    [ '/changes/NOAUTHOR/NODIST' => 404 ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ($path, $code, $name, $content) = @{ $test };
        ok( my $res = $cb->( GET $path), "GET $path" );
        is( $res->code, $code, "code $code" );
        is( $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );

        next unless $res->code == 200;

#        if ( $path eq '/distribution' ) {
#            ok( $json->{hits}->{total}, 'got total count' );
#        }

        is $json->{name}, $name, 'change log has expected name';
        like $json->{content},
            $content,
            'file content';
    }
};

done_testing;
