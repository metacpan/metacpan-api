use strict;
use warnings;

use lib 't/lib';

use Test::More 0.96;
use Path::Class qw(dir);

my $tmp_dir = dir('var/tmp');

unless ( -d $tmp_dir ) {
    $tmp_dir->mkpath();
}
ok( -d $tmp_dir, "var/tmp exists for testing" );

done_testing();
