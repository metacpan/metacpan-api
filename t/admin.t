use strict;
use warnings;
use lib 't/lib';

use Test::Fatal qw( exception );
use Test::Mojo;
use Test::More;

local $ENV{MOJO_SECRET}   = 'Magritte';
local $ENV{GITHUB_KEY}    = 'foo';
local $ENV{GITHUB_SECRET} = 'bar';

subtest 'authentication enabled' => sub {
    my $t = Test::Mojo->new('MetaCPAN::Admin');
    $t->post_ok('/admin/enqueue');
    $t->header_is( Location => '/auth/github/authenticate' );
    $t->status_is(302);
};

subtest 'missing secret' => sub {
    local $ENV{MOJO_SECRET} = q{};
    like( exception { Test::Mojo->new('MetaCPAN::Admin') }, qr{need secret} );
};

subtest 'index release' => sub {
    local $ENV{FORCE_ADMIN_AUTH} = 'tester';
    my $t = Test::Mojo->new('MetaCPAN::Admin');
    $t->get_ok('/admin/index-release');
    $t->status_is(200);
};

subtest 'search identities' => sub {
    local $ENV{FORCE_ADMIN_AUTH} = 'tester';
    my $t = Test::Mojo->new('MetaCPAN::Admin');
    $t->get_ok('/admin/identity-search-form');
    $t->status_is(200);

    $t->post_ok('/admin/search-identities');
    $t->status_is(200);
};

done_testing();
