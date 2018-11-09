use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::RequiresInternet ( 'cpan.metacpan.org' => 443 );

use Test::Mojo;

my $t   = Test::Mojo->new('MetaCPAN::API');
my $app = $t->app;

ok( $app, 'queue app' );
isa_ok $app, 'MetaCPAN::API';

my $release
    = 'https://cpan.metacpan.org/authors/id/O/OA/OALDERS/HTML-Restrict-2.2.2.tar.gz';

$app->minion->enqueue( index_release => [$release] );
$app->minion->enqueue( index_release => [ '--latest', $release ] );

$app->minion->perform_jobs;

done_testing();
