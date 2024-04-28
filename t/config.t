#!perl

use strict;
use warnings;

use MetaCPAN::Server::Config ();
use Test::More;

my $config = MetaCPAN::Server::Config::config();
ok($config);

done_testing();
