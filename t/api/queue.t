use strict;
use warnings;
use lib 't/lib';

use Test::More skip_all => 'disabling Minion tests to avoid needing postgres';
use MetaCPAN::TestHelpers qw( fakecpan_dir );
use Test::Mojo;

my $t   = Test::Mojo->new('MetaCPAN::API');
my $app = $t->app;

ok( $app, 'queue app' );
isa_ok $app, 'MetaCPAN::API';

my $release
    = fakecpan_dir()->child('authors/id/L/LO/LOCAL/File-Changes-1.0.tar.gz');

$app->minion->enqueue( index_release => [$release] );
$app->minion->enqueue( index_release => [ '--latest', $release ] );

$app->minion->perform_jobs;

done_testing();
