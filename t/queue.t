use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Admin   ();
use MetaCPAN::DarkPAN ();
use Path::Tiny qw( path );
use Test::More;

my $app = MetaCPAN::Admin->new;
ok( $app, 'queue app' );

my $darkpan = MetaCPAN::DarkPAN->new->base_dir;
my $release = path( $darkpan, 'authors/id/E/ET/ETHER/Try-Tiny-0.23.tar.gz' );

$app->minion->enqueue( index_release => [$release] );
$app->minion->enqueue( index_release => [ '--latest', $release ] );

$app->minion->perform_jobs;

done_testing();
