#!/usr/bin/env perl

use Modern::Perl;
use Find::Lib '../lib';
use MetaCPAN;

=head1 SYNOPSIS

To start with a new database. 

perl elasticsearch/loop_dists.pl --refresh_db 1

Keep in mind that the startup overhead is greater in this case as all modules
must first be inserted into the SQLite db.

=cut


# start with a clean db
my $refresh = 0;
my $cpan = MetaCPAN->new( refresh_db => $refresh);
$cpan->check_db;

$| = 1;

foreach my $alpha (reverse( 'a' .. 'z' ) ) {
    my $command = sprintf("/home/olaf/cpan-api/elasticsearch/index_dists.pl --dist_like %s%%", $alpha);
    say $alpha;
    `$command`;
}
