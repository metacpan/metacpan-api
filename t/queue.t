use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Queue;
use Test::More;
use Test::RequiresInternet ( 'cpan.metacpan.org' => 443 );

my $app = MetaCPAN::Queue->new;
ok( $app, 'queue app' );

my $release
    = 'https://cpan.metacpan.org/authors/id/O/OA/OALDERS/HTML-Restrict-2.2.2.tar.gz';

$app->minion->enqueue( index_release => [$release] );
$app->minion->enqueue( index_release => [ '--latest', $release ] );

$app->minion->perform_jobs;

done_testing();
