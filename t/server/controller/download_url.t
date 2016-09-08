use strict;
use warnings;

use Cpanel::JSON::XS ();
use HTTP::Request::Common qw( GET );
use MetaCPAN::Server ();
use Plack::Test;
use Test::More;
use Ref::Util qw(is_hashref);

my $app  = MetaCPAN::Server->new->to_app();
my $test = Plack::Test->create($app);

my @tests = (
    [ 'no parameters', '/download_url/Moose', 'latest', '0.02' ],
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
);

for (@tests) {
    my ( $title, $url, $status, $version ) = @$_;

    subtest $title => sub {
        my $res = $test->request( GET $url );
        ok( $res, "GET $url" );
        is( $res->code, 200, "code 200" );
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        my $content = Cpanel::JSON::XS::decode_json $res->content;
        ok( is_hashref($content), 'content is a JSON object' );
        is( $content->{status},  $status,  "correct status ($status)" );
        is( $content->{version}, $version, "correct version ($version)" );
    };
}

done_testing;
