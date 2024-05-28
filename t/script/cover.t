use strict;
use warnings;

use lib 't/lib';

use Git::Helpers            qw( checkout_root );
use MetaCPAN::Config        ();
use MetaCPAN::Script::Cover ();
use Test::More import => [qw( done_testing ok )];
use URI ();

my $config = MetaCPAN::Config::config();
$config->{es} = $config->{elasticsearch_servers};

my $root = checkout_root();
my $file = URI->new('t/var/cover.json')->abs("file://$root/");
$config->{'cover_url'} = "$file";

my $cover = MetaCPAN::Script::Cover->new_with_options($config);
ok $cover->run, 'runs and returns true';

done_testing();
