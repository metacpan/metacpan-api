#!/usr/bin/env perl

=head1 SYNOPSIS

Loads PerlMonger groups into db. 

    perl index_perlmongers.pl

=cut

use feature 'say';
use Data::Dump qw( dump );
use Find::Lib '../lib';
use MetaCPAN::Script::PerlMongers;

my $author = MetaCPAN::Script::PerlMongers->new;
my $result = $author->index_perlmongers;
say dump( $result );

$author->es->refresh_index( index => 'cpan' );
