use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET test_psgi );
use Test::More;

test_psgi app, sub {
    my $cb  = shift;
    my $res = $cb->( GET '/login' );
    is $res->code, 200, 'GET /login';
    like $res->content,   qr{/login/github},  'lists GitHub login';
    unlike $res->content, qr{/login/twitter}, 'does not list Twitter login';
};

done_testing;
