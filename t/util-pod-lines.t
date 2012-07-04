use warnings;
use strict;
use MetaCPAN::Util;
use FindBin;
use File::Slurp;
use Test::More tests => 3;
my $xsawyerx_file = "$FindBin::Bin/Everywhere.pm";
my $stuff = read_file ($xsawyerx_file);
my ($r, $s) = MetaCPAN::Util::pod_lines ($stuff);

ok (@$r == 2, "Got two bits of pod");
is ($r->[0]->[0], 47, "Start of first piece of pod.");
is ($r->[1]->[0], 92, "Start of last piece of pod.");

