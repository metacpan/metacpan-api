use strict;
use warnings;

use Cpanel::JSON::XS      ();
use HTTP::Request::Common qw( GET );
use MetaCPAN::Server      ();
use MetaCPAN::TestHelpers qw( test_cache_headers );
use Plack::Test           ();
use Ref::Util             qw( is_arrayref is_hashref );
use Test::More;

my $app  = MetaCPAN::Server->new->to_app();
my $test = Plack::Test->create($app);

subtest "parem 'source'" => sub {
    my $source = Cpanel::JSON::XS::encode_json {
        query => {
            term => { distribution => "Moose" }
        },
        aggs => {
            count => {
                terms => { field => "distribution" }
            }
        },
        size => 0,
    };

    # test different types, as the parameter is generic to all
    for ( [ release => 2 ], [ file => 27 ] ) {
        my ( $type, $count ) = @$_;

        my $url = "/$type/_search?source=$source";

        subtest "check with '$type' controller" => sub {
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

                }
            );
            is(
                $res->header('content-type'),
                'application/json; charset=utf-8',
                'Content-type'
            );
            my $content = Cpanel::JSON::XS::decode_json $res->content;
            ok( is_hashref($content), 'content is a JSON object' );
            my $buckets = $content->{aggregations}{count}{buckets};
            ok( is_arrayref($buckets), 'we have aggregation buckets' );
            is( @{$buckets},              1,      'one key (Moose)' );
            is( $buckets->[0]{doc_count}, $count, "record count is $count" );
        };
    }
};

done_testing;
