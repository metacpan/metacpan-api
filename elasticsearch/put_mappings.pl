#!/usr/bin/perl

=head1 SYNOPSIS

Rework module mappings.

=cut

use Modern::Perl;
use Data::Dump qw( dump );
use Find::Lib '../lib';
use MetaCPAN;

my $metacpan = MetaCPAN->new();
my $es       = $metacpan->es;

$metacpan->put_mappings;
