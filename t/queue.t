use strict;
use warnings;

use MetaCPAN::Queue;
use Test::More;

my $app = MetaCPAN::Queue->new;
ok( $app, 'queue app' );

my $release
    = 't/var/darkpan/authors/id/T/TI/TINITA/HTML-Template-Compiled-1.001.tar.gz';

$app->minion->enqueue( index_release => [$release] );
$app->minion->enqueue( index_release => [ '--latest', $release ] );

$app->minion->perform_jobs;

done_testing();
