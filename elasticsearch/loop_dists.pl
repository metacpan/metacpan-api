#!/usr/bin/env perl

use Modern::Perl;
$| = 1;

foreach my $alpha ( 'a' .. 'z' ) {
    my $command = sprintf("/home/olaf/cpan-api/elasticsearch/index_dists.pl %s%%", $alpha);
    say $alpha;
    `$command`;
}
