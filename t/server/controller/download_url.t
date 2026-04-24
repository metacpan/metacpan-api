use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS      ();
use Digest::file          qw( digest_file_hex );
use HTTP::Request::Common qw( GET );
use MetaCPAN::Server      ();
use MetaCPAN::TestHelpers qw( fakecpan_dir test_cache_headers );
use Plack::Test           ();
use Ref::Util             qw( is_hashref );
use Test::More;

my $app  = MetaCPAN::Server->new->to_app();
my $test = Plack::Test->create($app);

my $multi_rel_archive = fakecpan_dir()
    ->child('authors/id/H/HA/HAARG/Multiple-Releases-1.4.tar.gz');
my $multi_rel_md5    = digest_file_hex( $multi_rel_archive, 'MD5' );
my $multi_rel_sha256 = digest_file_hex( $multi_rel_archive, 'SHA-256' );

my @tests = (
    [ 'no parameters', '/download_url/Moose', 'latest', '0.02', ],
    [
        'version == (1)', '/download_url/Moose?version===0.01',
        'cpan',           '0.01'
    ],
    [
        'version == (2)', '/download_url/Moose?version===0.02',
        'latest',         '0.02'
    ],
    [
        'version != (1)', '/download_url/Moose?version=!=0.01',
        'latest',         '0.02'
    ],
    [
        'version != (2)', '/download_url/Moose?version=!=0.02',
        'cpan',           '0.01'
    ],
    [
        'version <= (1)', '/download_url/Moose?version=<=0.01',
        'cpan',           '0.01'
    ],
    [
        'version <= (2)', '/download_url/Moose?version=<=0.02',
        'latest',         '0.02'
    ],
    [ 'version >=', '/download_url/Moose?version=>=0.01', 'latest', '0.02' ],
    [
        'range >, <', '/download_url/Multiple::Releases?version=>1.1,<1.7',
        'cpan', '1.4', $multi_rel_md5, $multi_rel_sha256,
    ],
    [
        'range >, <, !',
        '/download_url/Multiple::Releases?version=>1.1,<1.7,!=1.4',
        'cpan', '1.3'
    ],
    [
        'range >, <; dev',
        '/download_url/Multiple::Releases?version=>1.1,<1.7&dev=1',
        'cpan', '1.6'
    ],
    [
        'range >, <, !; dev',
        '/download_url/Multiple::Releases?version=>1.1,<1.7,!=1.6&dev=1',
        'cpan', '1.5'
    ],

    [
        'dist: no parameters', '/download_url/distribution/Moose',
        'latest',              '0.02',
    ],
    [
        'dist: version ==',
        '/download_url/distribution/Moose?version===0.01',
        'cpan', '0.01'
    ],
    [
        'dist: version <=',
        '/download_url/distribution/Moose?version=<=0.01',
        'cpan', '0.01'
    ],
    [
        'dist: version >=',
        '/download_url/distribution/Moose?version=>=0.01',
        'latest', '0.02'
    ],
    [
        'dist: range >, <',
        '/download_url/distribution/Multiple-Releases?version=>1.1,<1.7',
        'cpan', '1.4', $multi_rel_md5, $multi_rel_sha256,
    ],
    [
        'dist: range >, <, !',
        '/download_url/distribution/Multiple-Releases?version=>1.1,<1.7,!=1.4',
        'cpan',
        '1.3'
    ],
    [
        'dist: range >, <; dev',
        '/download_url/distribution/Multiple-Releases?version=>1.1,<1.7&dev=1',
        'cpan',
        '1.6'
    ],
);

for (@tests) {
    my ( $title, $url, $status, $version, $checksum_md5, $checksum_sha256 )
        = @$_;

    subtest $title => sub {
        my $res = $test->request( GET $url );
        ok( $res, "GET $url" );
        is( $res->code, 200, "code 200" );

        test_cache_headers(
            $res,
            {
                cache_control => 'private',
                surrogate_key =>
                    'content_type=application/json content_type=application',
                surrogate_control => undef,
            },
        );

        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        my $content = Cpanel::JSON::XS::decode_json $res->content;
        ok( is_hashref($content), 'content is a JSON object' );
        is( $content->{status},  $status,  "correct status ($status)" );
        is( $content->{version}, $version, "correct version ($version)" );

        if ($checksum_md5) {
            is( $content->{checksum_md5},
                $checksum_md5, "correct checksum_md5 ($checksum_md5)" );
        }
        if ($checksum_sha256) {
            is( $content->{checksum_sha256},
                $checksum_sha256,
                "correct checksum_sha256 ($checksum_sha256)" );
        }
    };
}

subtest 'dist: not found' => sub {
    my $url = '/download_url/distribution/NotAThing';
    my $res = $test->request( GET $url );
    is( $res->code, 404, 'code 404' );
};

done_testing;
