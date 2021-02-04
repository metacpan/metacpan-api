use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw( decode_json_ok test_cache_headers );
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
    my $versions = get_json_ok(
        $cb,
        '/release/versions/Moose',
        'GET /release/versions/Moose',
        {
            # ???
        }
    );
    is( @{ $versions->{releases} }, 2, "Got 2 Moose versions (all)" );

    # versions - specific (/release/versions/DIST?versions=VERSION)
    my $versions_specific = get_json_ok(
        $cb,
        '/release/versions/Moose?versions=0.01',
        'GET /release/versions/Moose?versions=0.01',
        {
            # ???
        }
    );
    is( @{ $versions_specific->{releases} },
        1, "Got 1 Moose version (specificly requested)" );

    # versions - latest (/release/versions/DIST?versions=latest)
    my $versions_latest = get_json_ok(
        $cb,
        '/release/versions/Moose?versions=latest',
        'GET /release/versions/Moose?versions=latest',
        {
            # ???
        }
    );
    is( @{ $versions_latest->{releases} },
        1, "Got 1 Moose version (only latest requested)" );
    is( $versions_latest->{releases}[0]{status},
        'latest', "Release status is latest" );

    # versions - plain (/release/versions/DIST?plain=1)
    ok( my $versions_plain = $cb->( GET '/release/versions/Moose?plain=1' ),
        'GET /release/versions/Moose?plain=1' );
    is( $versions_plain->code, 200, 'code 200' );
    ok( $versions_plain->content =~ /\A .+ \t .+ \n .+ \t .+ \z/xsm,
        'Content is plain text result' );

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
