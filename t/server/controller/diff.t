use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;
use lib 't/lib';
use MetaCPAN::TestHelpers;
use Encode;

test_psgi app, sub {
    my $cb = shift;
    ok( my $res = $cb->( GET '/diff/release/Moose'), "GET /diff/Moose" );
    is( $res->code, 200, "code 200" );
    ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );

    diffed_file_like($json,
        'DOY/Moose-0.01',
        'DOY/Moose-0.02',
        'Changes' => qq|-2012-01-01  0.01  First release - codename 'M\xc3\xbcnchen'\n|,
    );

    ok( $res = $cb->( GET '/diff/release/DOY/Moose-0.01/DOY/Moose-0.02/'), "GET /diff/Moose/DOY..." );
    is( $res->code, 200, "code 200" );
    ok( my $json2 = eval { decode_json( $res->content ) }, 'valid json' );
    is_deeply($json, $json2, 'json matches with previous run');

    ok( $res = $cb->( GET '/diff/file/8yTixXQGpkbPsMBXKvDoJV4Qkg8/dPgxn7qq0wm1l_UO1aIMyQWFJPw'), "GET diff Moose.pm" );
    is( $res->code, 200, "code 200" );
    ok( $json = eval { decode_json( $res->content ) }, 'valid json' );

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
    my ($cb, $r1, $r2, $files) = @_;
    $files ||= {};

    my $res = $cb->( GET "/diff/release/$r1/$r2" );
    is( $res->code, 200, '200 OK' );
    ok( my $json = try { decode_json( $res->content ) }, 'valid json' );

    while( my ($file, $re) = each %$files ){
        diffed_file_like($json, $r1, $r2, $file, $re);
    }
}

sub diffed_file_like {
    my ($json, $r1, $r2, $file, $like) = @_;

    my $found = 0;
    foreach my $stat ( @{ $json->{statistics} } ){
        my $diff = $stat->{diff};
        # do byte comparison for these tests
        $diff = Encode::encode_utf8($diff)
            if utf8::is_utf8($diff);

        if( $stat->{source} eq diffed_file_name($r1, $file) ||
            $stat->{target} eq diffed_file_name($r2, $file)
        ){
            ++$found;
            my ($cmp, $desc) = ref($like) eq 'RegExp'
                ? ($diff =~ $like, "$file diff matched")
                : (index($diff, $like) >= 0, "substring found in $file diff");
            ok($cmp, $desc)
                or multiline_diag(substr => $like, diff => $diff);
        }
    }

    is $found, 1, "found one patch for $file";
}

sub diffed_file_name {
    my ($dir, $file) = @_;
    my ($root, $dist) = split /\//, $dir;
    # $dist x 2: once for the extraction dir,
    # once b/c Module::Faker makes good tars that have a root dir
    return qq{$root/$dist/$dist/$file};
}
