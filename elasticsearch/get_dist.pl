#!/usr/bin/env perl

use feature 'say';
use Data::Dump qw( dump );
use Find::Lib '../lib';
use MetaCPAN;
use Try::Tiny;

die "Usage: perl get_author.pl PAUSEID" if !@ARGV;

my $search = shift @ARGV;

my $metacpan = MetaCPAN->new;

#try {
#    my $get = $metacpan->es->get(
#        index => 'cpan',
#        type => 'dist',
#        id   => $search,
#    );
#    say dump( $get );
#
#}
#catch {
#    say "oops";
#}

my $result = $metacpan->es->search(
    index   => 'cpan',
    type    => 'dist',
    query   => { term => {name => lc($search) }}
);

say dump( $result );

if ( exists $result->{hits}->{hits} ) {
    foreach my $hit ( @{$result->{hits}->{hits}} ) {
        say $hit->{_source}->{name};
        if ( lc($hit->{_source}->{name}) eq lc( $search) ) {
            say '!'x20;
            last;
        }
    }
}
