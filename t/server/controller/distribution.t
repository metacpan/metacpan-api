use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestHelpers  qw( decode_json_ok test_cache_headers );
use MetaCPAN::Util         qw( hit_total );
use Test::More;

my @tests = (
    [
        '/distribution' => {
            code          => 200,
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
        }
    ],
    [
        '/distribution/DOESNEXIST' => {
            code          => 404,
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
        }
    ],
    [
        '/distribution/Moose' => {
            code          => 200,
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
            content           => {
                name   => 'Moose',
                'bugs' => {
                    'rt' => {
                        'active'   => 39,
                        'closed'   => 145,
                        'new'      => 15,
                        'open'     => 20,
                        'patched'  => 0,
                        'rejected' => 23,
                        'resolved' => 122,
                        'source'   =>
                            'https://rt.cpan.org/Public/Dist/Display.html?Name=Moose',
                        'stalled' => 4,
                    },
                },
            },
        }
    ],
    [
        '/distribution/System-Command' => {
            code          => 200,
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
            content           => {
                name  => 'System-Command',
                river => {
                    total      => 92,
                    immediate  => 4,
                    bucket     => 2,
                    bus_factor => 2,
                },
            },
        }
    ],
    [
        '/distribution/Text-Markdown' => {
            code          => 200,
            cache_control => 'private',
            surrogate_key =>
                'content_type=application/json content_type=application',
            surrogate_control => undef,
            content           => {
                name    => 'Text-Markdown',
                'river' => {
                    total      => 92,
                    immediate  => 56,
                    bucket     => 2,
                    bus_factor => 1,
                },
            },
        }
    ],
);

test_psgi app, sub {
    my $cb = shift;
    for my $test (@tests) {
        my ( $k, $v ) = @{$test};
        ok( my $res = $cb->( GET $k ), "GET $k" );

        # TRAVIS 5.18
        is( $res->code, $v->{code}, "code " . $v->{code} );
        is(
            $res->header('content-type'),
            'application/json; charset=utf-8',
            'Content-type'
        );
        test_cache_headers( $res, $v );

        my $json = decode_json_ok($res);
        if ( $k eq '/distribution' ) {
            ok( hit_total($json), 'got total count' );
        }
        elsif ( my $wanted = $v->{content} ) {
            is_deeply $json, $wanted, 'has correct content'
                or diag explain $json;
        }
    }
};

done_testing;
