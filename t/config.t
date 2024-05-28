#!perl

use strict;
use warnings;

use MetaCPAN::Config ();
use Test::More import => [qw( done_testing ok )];

my $config = MetaCPAN::Config::config();
ok($config);

done_testing();
