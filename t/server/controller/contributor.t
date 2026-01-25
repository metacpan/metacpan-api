use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS       qw( decode_json );
use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestServer   ();
use Test::More;

my $server = MetaCPAN::TestServer->new;

test_psgi app, sub {
    my $cb = shift;

    {
        my $release_name = 'LOCAL/HasContributors-1.0';
        ok( my $res = $cb->( GET "/contributor/$release_name" ),
            "GET contributors for $release_name" );
        is( $res->code, 200, '200 OK' );

        is_deeply(
            decode_json( $res->content ),
            {
                contributors => [
                    {
                        "distribution"   => "HasContributors",
                        "pauseid"        => "REAL",
                        "release_author" => "LOCAL",
                        "release_name"   => "HasContributors-1.0",
                    },
                    {
                        "distribution"   => "HasContributors",
                        "pauseid"        => "CONTRIBUTOR",
                        "release_author" => "LOCAL",
                        "release_name"   => "HasContributors-1.0",
                    },
                    {
                        "distribution"   => "HasContributors",
                        "pauseid"        => "AUTHOR",
                        "release_author" => "LOCAL",
                        "release_name"   => "HasContributors-1.0",
                    },
                ],
            },
            'Has the correct contributors info'
        );
    }
};

done_testing;
