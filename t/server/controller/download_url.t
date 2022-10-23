use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS      ();
use HTTP::Request::Common qw( GET );
use MetaCPAN::Server      ();
use MetaCPAN::TestHelpers qw( test_cache_headers );
use Plack::Test           ();
use Test::More;
use Ref::Util qw( is_hashref );

my $app  = MetaCPAN::Server->new->to_app();
my $test = Plack::Test->create($app);

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
        'range >, <',
        '/download_url/Try::Tiny?version=>0.21,<0.27',
        'cpan',
        '0.24',
        '1a12a51cfeb7e2c301e4ae093c7ecdfb',
        '9b7a1af24c0256973d175369ebbdc25ec01e2452a97f2d3ab61481c826f38d81',
    ],
    [
        'range >, <, !',
        '/download_url/Try::Tiny?version=>0.21,<0.27,!=0.24',
        'cpan', '0.23'
    ],
    [
        'range >, <; dev',
        '/download_url/Try::Tiny?version=>0.21,<0.27&dev=1',
        'cpan', '0.26'
    ],
    [
        'range >, <, !; dev',
        '/download_url/Try::Tiny?version=>0.21,<0.27,!=0.26&dev=1',
        'cpan', '0.25'
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

done_testing;
