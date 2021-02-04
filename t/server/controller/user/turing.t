use strict;
use warnings;
use lib 't/lib';

{
    package    ## no critic (Package)
        Captcha::Mock;

    sub check_answer_v2 {
        return { is_valid => $_[2], error => 'error' };
    }

    sub new {
        bless {}, shift;
    }
}

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw( decode_json_ok encode_json );
use Test::More;

test_psgi app, sub {
    my $cb = shift;
    ok(
        my $res = $cb->(
            POST '/user/turing?access_token=bot',
            Content => encode_json(
                {
                    challenge => 'foo',
                    answer    => 0
                }
            )
        ),
        'post challenge'
    );
    is( $res->code, 400, 'bad request' );

    ok(
        $res = $cb->(
            POST '/user/turing?access_token=bot',
            Content => encode_json(
                {
                    challenge => 'foo',
                    answer    => 1,
                }
            )
        ),
        'post challenge'
    );

    is( $res->code, 200, 'successful request' );

    my $user = decode_json_ok($res);
    ok( $user->{looks_human},    'looks human' );
    ok( $user->{passed_captcha}, 'passed captcha' );
};

done_testing;
