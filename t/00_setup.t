use strict;
use warnings;

use lib 't/lib';

use Path::Class qw(dir);
use Test::More 0.96;

my $tmp_dir = dir('var/tmp');

unless ( -d $tmp_dir || -l $tmp_dir ) {
    $tmp_dir->mkpath();
}
ok( ( -d $tmp_dir || -l $tmp_dir ), 'var/tmp exists for testing' );

done_testing();
