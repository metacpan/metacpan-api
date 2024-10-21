use strict;
use warnings;

use lib 't/lib';

use MetaCPAN::Script::Cover  ();
use MetaCPAN::Server::Config ();
use MetaCPAN::Util           qw( root_dir );
use Test::More;
use URI ();

my $root = root_dir();
my $file = URI->new('t/var/cover.json')->abs("file://$root/");

my $config = MetaCPAN::Server::Config::config();
$config->{cover_url} = "$file";

my $cover = MetaCPAN::Script::Cover->new_with_options($config);
ok $cover->run, 'runs and returns true';

done_testing();
