use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS qw( decode_json );
use MetaCPAN::Server::Test;
use MetaCPAN::TestServer;
use Test::More;

my $server = MetaCPAN::TestServer->new;

test_psgi app, sub {
    my $cb = shift;

    {
        my $release_name = 'DOY/Try-Tiny-0.22';
        ok( my $res = $cb->( GET "/contributor/$release_name" ),
            "GET contributors for $release_name" );
        is( $res->code, 200, '200 OK' );

        is_deeply(
            decode_json( $res->content ),
            {
                contributors => [
                    {
                        "release_name"   => "Try-Tiny-0.22",
                        "pauseid"        => "CEBJYRE",
                        "distribution"   => "Try-Tiny",
                        "release_author" => "DOY"
                    },
                    {
                        "distribution"   => "Try-Tiny",
                        "release_author" => "DOY",
                        "pauseid"        => "JAWNSY",
                        "release_name"   => "Try-Tiny-0.22"
                    },
                    {
                        "release_name"   => "Try-Tiny-0.22",
                        "pauseid"        => "ETHER",
                        "distribution"   => "Try-Tiny",
                        "release_author" => "DOY"
                    },
                    {
                        "release_author" => "DOY",
                        "distribution"   => "Try-Tiny",
                        "pauseid"        => "RIBASUSHI",
                        "release_name"   => "Try-Tiny-0.22"
                    },
                    {
                        "pauseid"        => "RJBS",
                        "release_author" => "DOY",
                        "distribution"   => "Try-Tiny",
                        "release_name"   => "Try-Tiny-0.22"
                    }
                ]
            },
            'Has the correct contributors info'
        );
    }
};

done_testing;
