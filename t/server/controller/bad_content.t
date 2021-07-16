use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS ();
use MetaCPAN::Server ();
use MetaCPAN::TestHelpers;
use Plack::Test;
use Test::More;
use Ref::Util qw( is_arrayref is_hashref );

my $app  = MetaCPAN::Server->new->to_app();
my $test = Plack::Test->create($app);

subtest "broken body content" => sub {
    my $source = q[
        { "query : { } }
    ];

    for my $type (qw( release file )) {
        my $url     = "/$type/_search";
        my $request = HTTP::Request->new( 'POST', $url, [], $source );

        subtest "check with '$type' controller" => sub {
            my $res = $test->request($request);

            ok( $res, "GET $url" );
            is( $res->code, 400, "code 400" );
            is(
                $res->header('content-type'),
                'application/json; charset=utf-8',
                'Content-type'
            );
            my $content
                = eval { Cpanel::JSON::XS::decode_json( $res->content ) };
            ok( is_hashref($content), 'content is a JSON object' );
            ok $content->{error}, 'content includes includes error';
        };
    }
};

done_testing;
