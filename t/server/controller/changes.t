use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestHelpers  qw( decode_json_ok test_cache_headers );
use Test::More;

my $LOCAL_default_headers = {
    cache_control => undef,
    surrogate_key =>
        'author=LOCAL content_type=application/json content_type=application',
    surrogate_control =>
        'max-age=31556952, stale-while-revalidate=86400, stale-if-error=2592000',
};

my $RWSTAUNER_default_headers = {
    cache_control => undef,
    surrogate_key =>
        'author=RWSTAUNER content_type=application/json content_type=application',
    surrogate_control =>
        'max-age=31556952, stale-while-revalidate=86400, stale-if-error=2592000',
};

my @tests = (
    [
        '/changes/File-Changes' => 200,
        Changes => qr/^Revision history for Changes\n\n2\.0.+1\.0.+/sm,
        $LOCAL_default_headers,
    ],
    [
        '/changes/LOCAL/File-Changes-2.0' => 200,
        Changes => qr/^Revision history for Changes\n\n2\.0.+1\.0.+/sm,
        $LOCAL_default_headers,
    ],
    [
        '/changes/LOCAL/File-Changes-1.0' => 200,
        Changes => qr/^Revision history for Changes\n\n1\.0.+/sm,
        $LOCAL_default_headers,
    ],
    [
        '/changes/File-Changes-News' => 200,
        NEWS                         => qr/^F\nR\nE\nE\nF\nO\nR\nM\n/,
        $LOCAL_default_headers,
    ],
    [
        '/changes/LOCAL/File-Changes-News-11.22' => 200,
        NEWS => qr/^F\nR\nE\nE\nF\nO\nR\nM\n/,
        $LOCAL_default_headers,
    ],
    [
        '/changes/NOEXISTY' => 404,
        '',
        {
            cache_control => undef,
            surrogate_key =>
                'author=NOEXISTY content_type=application/json content_type=application',
            surrogate_control =>
                'max-age=31556952, stale-while-revalidate=86400, stale-if-error=2592000',
        }
    ],
    [
        '/changes/NOAUTHOR/NODIST' => 404,
        '',
        {
            cache_control => undef,
            surrogate_key =>
                'author=NOAUTOR content_type=application/json content_type=application',
            surrogate_control =>
                'max-age=31556952, stale-while-revalidate=86400, stale-if-error=2592000',
        }
    ],

    # Don't search for all files.
    [ '/changes' => 404, '', $LOCAL_default_headers ],

    # NOTE: We need to use author/release because in these tests
    # 'perl' doesn't get flagged as latest.
    [
        '/changes/RWSTAUNER/perl-1' => 200,
        'perldelta.pod'             =>
            qr/^=head1 NAME\n\nperldelta - changes for perl\n\n/m,
        $RWSTAUNER_default_headers,
    ],
    [
        '/changes/File-Changes-UTF8' => 200,
        'Changes' => qr/^  - 23E7 \x{23E7} ELECTRICAL INTERSECTION/m,
        $RWSTAUNER_default_headers,
    ],
    [
        '/changes/File-Changes-Latin1' => 200,
        'Changes'                      => qr/^  - \244 CURRENCY SIGN/m,
        $RWSTAUNER_default_headers,
    ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ( $path, $code, $name, $content, $headers ) = @{$test};

        my $res  = get_ok( $cb, $path, $code );
        my $json = decode_json_ok($res);

        test_cache_headers( $res, $headers );

        next unless $res->code == 200;

        is $json->{name}, $name, 'change log has expected name';
        like $json->{content}, $content, 'file content';

        my @fields = qw(release name content);
        $res  = get_ok( $cb, "$path?fields=" . join( q[,], @fields ), 200 );
        $json = decode_json_ok($res);

        is_deeply [ sort keys %$json ], [ sort @fields ],
            'only requested fields';
        like $json->{content}, $content, 'content as expected';
        is $json->{name}, $name, 'name as expected';

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

    ok( my $res = $cb->( GET $path ), "GET $path" );
    is( $res->code, $code, "code $code" );
    is(
        $res->header('content-type'),
        'application/json; charset=utf-8',
        'Content-type'
    );
    return $res;
}
