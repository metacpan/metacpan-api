use strict;
use warnings;

use Encode;
use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

{
    no warnings 'redefine';

    sub get_ok {
        my ( $cb, $url, $desc ) = @_;
        ok( my $res = $cb->( GET $url ), $desc || "GET $url" );
        is( $res->code, 200, 'code 200' );
        return $res;
    }
}

sub get_json_ok {
    return decode_json_ok( get_ok(@_) );
}

test_psgi app, sub {
    my $cb = shift;

    my $dist_url = '/diff/release/Moose';
    my $json = get_json_ok( $cb, $dist_url, 'GET /diff/dist' );

    diffed_file_like( $json, 'DOY/Moose-0.01', 'DOY/Moose-0.02',
        'Changes' =>
            qq|-2012-01-01  0.01  First release - codename 'M\xc3\xbcnchen'\n|,
    );

    my $plain = plain_text_diff_ok(
        $cb,
        plain_text_url($dist_url),
        'plain text dist diff',
    );

    like(
        $plain,

        # Encoding will be mangled, so relax the test slightly.
        qr|^-2012-01-01  0.01  First release - codename '.+?'$|m,
        'found expected diff test on whole line'
    );

    my $release_url = '/diff/release/DOY/Moose-0.01/DOY/Moose-0.02/';
    my $json2       = get_json_ok( $cb, $release_url,
        'GET /diff/author/release/author/release' );

    my $plain2 = plain_text_diff_ok(
        $cb,
        plain_text_url($release_url),
        'plain text release diff',
    );

    is_deeply( $json, $json2, 'json matches with previous run' );
    is $plain, $plain2, 'plain text diffs are the same';

    my $file_url
        = '/diff/file/8yTixXQGpkbPsMBXKvDoJV4Qkg8/dPgxn7qq0wm1l_UO1aIMyQWFJPw';
    $json = get_json_ok( $cb, $file_url, 'GET diff Moose.pm' );

    $plain = plain_text_diff_ok(
        $cb,
        plain_text_url($file_url),
        'plain text file url'
    );

    diffed_file_like(
        $json,
        'DOY/Moose-0.01',
        'DOY/Moose-0.02',
        'lib/Moose.pm' => <<DIFF,
-our \$VERSION = '0.01';
+our \$VERSION = '0.02';
DIFF
        { type => 'file' },
    );

    foreach my $chars ( [ q[-], 1 ], [ q[+], 2 ] ) {
        like $plain,
            qr/^\Q$chars->[0]\Eour \$VERSION = '0.0\Q$chars->[1]\E';$/m,
            'diff has insert and delete on whole lines';
    }

    diff_releases(
        $cb,
        'RWSTAUNER/Encoding-1.0',
        'RWSTAUNER/Encoding-1.1',
        {
            'lib/Encoding/CP1252.pm' => <<DIFF,
-sub bullet { qq<\xe2\x80\xa2> }
+sub bullet { qq<\xe2\x80\xa2-\xc3\xb7> }
DIFF
        },
    );

    diff_releases(
        $cb,
        'RWSTAUNER/Encoding-1.1',
        'RWSTAUNER/Encoding-1.2',
        {
            'lib/Encoding/UTF8.pm' => <<DIFF,
-my \$heart = qq<\342\235\244>;
+my \$heart = qq<\342\231\245>;
DIFF
        },
    );
};

done_testing;

sub diff_releases {
    my ( $cb, $r1, $r2, $files ) = @_;
    my $url = "/diff/release/$r1/$r2";
    subtest $url, sub {
        do_release_diff( $cb, $url, $r1, $r2, $files );
    };
}

sub do_release_diff {
    my ( $cb, $url, $r1, $r2, $files ) = @_;
    $files ||= {};

    my $json = get_json_ok( $cb, $url );

    while ( my ( $file, $re ) = each %$files ) {
        diffed_file_like( $json, $r1, $r2, $file, $re );
    }

    return $json;
}

sub diffed_file_like {
    my ( $json, $r1, $r2, $file, $like, $opts ) = @_;
    $opts ||= {};
    $opts->{type} ||= 'dir';

    my %pairs = ( source => $r1, target => $r2 );
    while ( my ( $which, $dir ) = each %pairs ) {

        # For release (dir) diff, source/target will be release (dir).
        # For file diff they will start with dir but have the file on the end.
        is $json->{$which},
            ( $dir . ( $opts->{type} eq 'file' ? "/$file" : q[] ) ),
            "diff $which";
    }

    my $found = 0;
    foreach my $stat ( @{ $json->{statistics} } ) {
        my $diff = $stat->{diff};

        # do byte comparison for these tests
        $diff = Encode::encode_utf8($diff)
            if utf8::is_utf8($diff);

        if (   diffed_file_name_eq( $stat->{source}, $r1, $file )
            || diffed_file_name_eq( $stat->{target}, $r2, $file ) )
        {
            ++$found;
            my ( $cmp, $desc )
                = ref($like) eq 'RegExp'
                ? ( $diff =~ $like, "$file diff matched" )
                : (
                index( $diff, $like ) >= 0,
                "substring found in $file diff"
                );
            ok( $cmp, $desc )
                or multiline_diag( substr => $like, diff => $diff );
        }
    }

    is $found, 1, "found one patch for $file";
}

sub diffed_file_name_eq {
    my ( $str, $dir, $file ) = @_;
    my ( $root, $dist ) = split /\//, $dir;

    # $dist x 2: once for the extraction dir,
    # once b/c Module::Faker makes good tars that have a root dir
    return $str eq qq{$root/$dist/$dist/$file};
}

sub plain_text_url {
    return $_[0] . '?content-type=text/plain';
}

sub plain_text_diff_ok {
    my $plain = get_ok(@_)->content;
    like $plain, qr|\Adiff|, 'plain text format is not json';
    return $plain;
}
