#!/usr/bin/env perl

use Data::Dump qw( dump );
use JSON::Any;
use feature 'say';
use WWW::Mechanize::Cached;

my $j = JSON::Any->new;

my $mech = WWW::Mechanize::Cached->new( autocheck => 0 );

$mech->get("http://www.cpantesters.org/distro/P/Plack-Middleware-HTMLify.json");
my $reports = $j->decode( $mech->content );

my %results = ( );
foreach my $test ( @{$reports} ) {
    next if $test->{distversion} ne 'Plack-Middleware-HTMLify-0.1.1';
    ++$results{ $test->{state} };
}

say dump( \%results );
