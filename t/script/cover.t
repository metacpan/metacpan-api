use strict;
use warnings;

use lib 't/lib';

use MetaCPAN::Script::Cover  ();
use MetaCPAN::Server::Config ();
use MetaCPAN::Util           qw( checkout_root );
use Test::More;
use URI ();

my $root = checkout_root();
my $file = URI->new('t/var/cover.json')->abs("file://$root/");

my $config = MetaCPAN::Server::Config::config();
$config->{cover_url} = "$file";

my $cover = MetaCPAN::Script::Cover->new_with_options($config);
ok $cover->run, 'runs and returns true';

done_testing();
