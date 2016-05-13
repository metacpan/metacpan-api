use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

my @tests = (
    [
        '/changes/File-Changes' => 200,
        Changes => qr/^Revision history for Changes\n\n2\.0.+1\.0.+/sm,
    ],
    [
        '/changes/LOCAL/File-Changes-2.0' => 200,
        Changes => qr/^Revision history for Changes\n\n2\.0.+1\.0.+/sm,
    ],
    [
        '/changes/LOCAL/File-Changes-1.0' => 200,
        Changes => qr/^Revision history for Changes\n\n1\.0.+/sm,
    ],
    [
        '/changes/File-Changes-News' => 200,
        NEWS                         => qr/^F\nR\nE\nE\nF\nO\nR\nM\n/,
    ],
    [
        '/changes/LOCAL/File-Changes-News-11.22' => 200,
        NEWS => qr/^F\nR\nE\nE\nF\nO\nR\nM\n/,
    ],
    [ '/changes/NOEXISTY'        => 404 ],
    [ '/changes/NOAUTHOR/NODIST' => 404 ],

    # Don't search for all files.
    [ '/changes' => 404 ],

    # NOTE: We need to use author/release because in these tests
    # 'perl' doesn't get flagged as latest.
    [
        '/changes/RWSTAUNER/perl-1' => 200,
        'perldelta.pod' =>
            qr/^=head1 NAME\n\nperldelta - changes for perl\n\n/m,
    ],
    [
        '/changes/File-Changes-UTF8' => 200,
        'Changes' => qr/^  - 23E7 \x{23E7} ELECTRICAL INTERSECTION/m,
    ],
    [
        '/changes/File-Changes-Latin1' => 200,
        'Changes'                      => qr/^  - \244 CURRENCY SIGN/m,
    ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ( $path, $code, $name, $content ) = @{$test};

        my $res = get_ok( $cb, $path, $code );
        my $json = decode_json_ok($res);

        next unless $res->code == 200;

        is $json->{name},      $name,    'change log has expected name';
        like $json->{content}, $content, 'file content';

        my @fields = qw(release name content);
        $res = get_ok( $cb, "$path?fields=" . join( q[,], @fields ), 200 );
        $json = decode_json_ok($res);

        is_deeply [ sort keys %$json ], [ sort @fields ],
            'only requested fields';
        like $json->{content}, $content, 'content as expected';
        is $json->{name},      $name,    'name as expected';

        {
            my $suffix = 'v?[0-9.]+';    # wrong, but good enough
            my $prefix = ( $path =~ m{([^/]+?)(-$suffix)?$} )[0];
            like $json->{release}, qr/^\Q$prefix\E-$suffix$/,
                'release as expected';
        }
    }
};

done_testing;

sub get_ok {
    my ( $cb, $path, $code ) = @_;

    ok( my $res = $cb->( GET $path), "GET $path" );
    is( $res->code, $code, "code $code" );
    is(
        $res->header('content-type'),
        'application/json; charset=utf-8',
        'Content-type'
    );
    return $res;
}
