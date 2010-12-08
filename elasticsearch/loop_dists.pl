#!/usr/bin/env perl

use Modern::Perl;
use Find::Lib '../lib';
use MetaCPAN;

# start with a clean db
my $cpan = MetaCPAN->new( refresh_db => 1 );
$cpan->check_db;

$| = 1;

foreach my $alpha (reverse( 'a' .. 'z' ) ) {
    my $command = sprintf("/home/olaf/cpan-api/elasticsearch/index_dists.pl --dist_name %s%%", $alpha);
    say $alpha;
    `$command`;
}
