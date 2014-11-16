use strict;
use warnings;

use Encode;
use MetaCPAN::Server::Test;
use Test::More;

use lib 't/lib';

use MetaCPAN::TestHelpers;

sub get_json_ok {
    my ( $cb, $url, $desc ) = @_;
    ok( my $res = $cb->( GET $url ), $desc || "GET $url" );
    is( $res->code, 200, 'code 200' );
    return decode_json_ok($res);
}

test_psgi app, sub {
    my $cb = shift;
    my $json = get_json_ok( $cb, '/diff/release/Moose', 'GET /diff/dist' );

    diffed_file_like( $json, 'DOY/Moose-0.01', 'DOY/Moose-0.02',
        'Changes' =>
            qq|-2012-01-01  0.01  First release - codename 'M\xc3\xbcnchen'\n|,
    );

    my $json2 = get_json_ok(
        $cb,
        '/diff/release/DOY/Moose-0.01/DOY/Moose-0.02/',
        'GET /diff/author/release/author/release'
    );

    is_deeply( $json, $json2, 'json matches with previous run' );

    $json = get_json_ok(
        $cb,
        '/diff/file/8yTixXQGpkbPsMBXKvDoJV4Qkg8/dPgxn7qq0wm1l_UO1aIMyQWFJPw',
        'GET diff Moose.pm'
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
