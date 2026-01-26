use strict;
use warnings;

use lib 't/lib';

use MetaCPAN::Script::Cover  ();
use MetaCPAN::Server::Config ();
use MetaCPAN::TestHelpers    qw( testdata_dir );
use Test::More;
use URI ();

my $file = URI->new( 'file://' . testdata_dir()->child('cover.json') );

my $config = MetaCPAN::Server::Config::config();
$config->{cover_url} = "$file";

my $cover = MetaCPAN::Script::Cover->new_with_options($config);
ok $cover->run, 'runs and returns true';

done_testing();
