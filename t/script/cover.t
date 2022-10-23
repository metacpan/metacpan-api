use strict;
use warnings;
use lib 't/lib';

use Git::Helpers             qw( checkout_root );
use MetaCPAN::Script::Cover  ();
use MetaCPAN::Script::Runner ();
use Test::More;
use URI ();

my $config = MetaCPAN::Script::Runner::build_config;

my $root = checkout_root();
my $file = URI->new('t/var/cover.json')->abs("file://$root/");
$config->{'cover_url'} = "$file";

my $cover = MetaCPAN::Script::Cover->new_with_options($config);
ok $cover->run, 'runs and returns true';

done_testing();
