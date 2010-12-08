#!/usr/bin/env perl

=head1 SYNOPSIS

Loads author info into db. 

    perl index_authors.pl

=cut

use Modern::Perl;
use Find::Lib '../lib';
use MetaCPAN::Author;

use MetaCPAN;
my $author = MetaCPAN::Author->new;

$author->index_authors;
