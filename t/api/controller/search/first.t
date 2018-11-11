use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::JSON qw(true false);

plan skip_all =>
    "Travis ES bad, see https://travis-ci.org/metacpan/metacpan-api/jobs/301092129"
    if $ENV{TRAVIS};

my $t = Test::Mojo->new('MetaCPAN::API');

$t->get_ok( '/v1/search/first', form => { q => 'Versions::PkgVar' } )
    ->status_is(200)->json_like( '/release' => qr/Versions-(?:\d+)/ );

$t->get_ok( '/v1/search/first', form => { q => 'DOESNOTEXISTS' } )
    ->status_is(404)->content_is('');

done_testing;

