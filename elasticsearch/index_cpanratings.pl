#!/usr/bin/perl

=head2 SYNOPSIS

Loads module ratings into module table.  Requires the following file
in the /perl directory:

http://cpanratings.perl.org/csv/all_ratings.csv

=cut

use Data::Dump qw( dump );
use Find::Lib '../lib';
use MetaCPAN;
use Modern::Perl;
use Parse::CSV;
use Path::Class::File;
use WWW::Mechanize::Cached;

my $es       = MetaCPAN->new->es;
my $filename = '/tmp/all_ratings.csv';
my $file     = Path::Class::File->new( $filename );
my $mech     = WWW::Mechanize::Cached->new;

$mech->get( 'http://cpanratings.perl.org/csv/all_ratings.csv' );
my $fh = $file->openw();
print $fh $mech->content;

my $parser = Parse::CSV->new(
    file   => $filename,
    fields => 'auto',
);

my @to_insert = ();

while ( my $rating = $parser->fetch ) {

    my $dist_name = $rating->{distribution};

    my $data = {
        dist         => $rating->{distribution},
        rating       => $rating->{rating},
        review_count => $rating->{review_count},
    };

    my %es_insert = (
        index => {
            index => 'cpan',
            type  => 'cpanratings',
            id    => $rating->{distribution},
            data  => $data
        }
    );

    push @to_insert, \%es_insert;

}

my $result = $es->bulk( \@to_insert );

unlink $filename;
