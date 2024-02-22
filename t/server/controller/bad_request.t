use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS qw( decode_json );
use MetaCPAN::Server ();
use Plack::Test      ();
use Test::More;
use Ref::Util qw( is_hashref );

my $app  = MetaCPAN::Server->new->to_app();
my $test = Plack::Test->create($app);

my $sbigqueryjson = q({
    "query": {
        "query_string": {
            "query": "cpanfile"
        }
    },
    "filter": {
        "and": [
            {
                "term": {
                    "status": "latest"
                }
            }
        ]
    },
    "fields": ["distribution", "release", "module.name", "name", "path", "download_url"],
    "size": "5001"
});

my @tests = (
    [
        'broken body content',
        400,
        q[ { "query : { } } ],
        'error',
        'unexpected end of string',
    ],
    [
        'plain text query',
        400,     'some content as invalid JSON',
        'error', 'malformed JSON string',
    ],
    [
        'big result query', 416, $sbigqueryjson, 'message', 'exceeds maximum',
    ],
);

for (@tests) {
    my ( $title, $code, $query, $field, $check ) = @$_;

    subtest $title => sub {
        for my $type (qw( release file )) {
            my $url     = "/$type/_search";
            my $request = HTTP::Request->new( 'POST', $url, [], $query );

            subtest "check with '$type' controller" => sub {
                my $res = $test->request($request);

                ok( $res, "GET $url" );
                is( $res->code, $code, "code [$code] as expected" );
                is(
                    $res->header('content-type'),
                    'application/json; charset=utf-8',
                    'Content-type'
                );
                my $content = eval { decode_json( $res->content ) };
                ok( is_hashref($content), 'response is a JSON object' );
                ok $content->{$field}, "response includes field '$field'";
                ok $content->{$field} =~ /$check/i,
                    'response error message as expected';
            };
        }
    };
}

done_testing;
