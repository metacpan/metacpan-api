#!/usr/bin/env perl

=head1 SYNOPSIS

Loads author info into db. 

    perl index_authors.pl

=cut

use Modern::Perl;
use Data::Dump qw( dump );
use Find::Lib '../lib';
use MetaCPAN::Author;

my $author = MetaCPAN::Author->new;
my $result = $author->index_authors;
#say dump( $result );

$author->es->refresh_index( index => 'cpan' );
