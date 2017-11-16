use strict;
use warnings;

use Encode;
use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

{
    no warnings 'redefine';

    sub get_ok {
        my ( $cb, $url, $desc, $headers ) = @_;
        ok( my $res = $cb->( GET $url ), $desc || "GET $url" );
        is( $res->code, 200, 'code 200' );

        test_cache_headers( $res, $headers );

        return $res;
    }
}

sub get_json_ok {
    return decode_json_ok( get_ok(@_) );
}

test_psgi app, sub {
    my $cb = shift;

    # find (/release/DIST)
    get_json_ok(
        $cb,
        '/release/Moose',
        'GET /release/dist',
        {
            # ???
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
        }
    );

    # get (/release/AUTHOR/NAME)
    get_json_ok(
        $cb,
        '/release/DOY/Moose-0.01',
        'GET /release/DOY/Moose-0.01',
        {
            # ???
        }
    );

    # versions (/release/versions/DIST)
    get_json_ok(
        $cb,
        '/release/versions/Moose',
        'GET /release/versions/Moose',
        {
            # ???
        }
    );

    # latest_by_distribution (/release/latest_by_distribution/DIST)
    get_json_ok(
        $cb,
        '/release/latest_by_distribution/Moose',
        'GET /release/latest_by_distribution/Moose',
        {
            # ???
        }
    );
};

done_testing;

