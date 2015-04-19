use strict;
use warnings;

use lib 't/lib';

use MetaCPAN::DarkPAN;
use MetaCPAN::TestServer;
use Test::More;
use Test::RequiresInternet ( 'cpan.metacpan.org' => 80 );

my $darkpan = MetaCPAN::DarkPAN->new;
my $server = MetaCPAN::TestServer->new( cpan_dir => $darkpan->base_dir );

# create DarkPAN
$darkpan->run;

$server->index_releases( bulk_size => 1 );

done_testing();
