#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  cpanratings.pl
#
#        USAGE:  ./cpanratings.pl  
#
#  DESCRIPTION: Screen-scrapper for cpanratings.perl.org's ratings and reviews 
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  usage - perl cpanratings.pl Data::Dumper
#       AUTHOR:  J. Bobby Lopez (blopez), blopez@vmware.com, bobby.lopez@gmail.com
#      COMPANY:  CPAN-API Project
#      VERSION:  1.0
#      CREATED:  11/11/10 05:01:10 PM
#     REVISION:  ---
#===============================================================================

#_______________________________________________________________[[ MODULES ]]_

#______________________________________[ Core or CPAN Modules ]_______________

use strict;
use warnings;
use Find::Lib '../lib';
use Data::Dumper;
use Data::Dump;

use List::Util qw(sum);
use WWW::Mechanize::Cached;
use HTML::TokeParser::Simple;
use Cpanel::JSON::XS;
use Parse::CSV;
use Path::Class::File;
use feature 'say';

#______________________________________[ Custom Modules ]_____________________

#use MetaCPAN;

#__________________________________________________________________[[ SETUP ]]_

# Incoming arg = module name (e.g., Data::Dumper)
# would pull info from http://cpanratings.perl.org/dist/Data-Dumper

my $dbg = 1;
my $cacher = WWW::Mechanize::Cached->new;
#my $es       = MetaCPAN->new->es;

prep_for_web();

#___________________________________________________________________[[ MAIN ]]_



my @to_insert = dump_all_ratings();
#print Dumper( @to_insert );


#dump_full_html(); # For testing - cleans up the HTML a bit before output
#print Dumper(\%ENV);

#DONE

#____________________________________________________________[[ SUBROUTINES ]]_

sub get_module_ratings
{
    my ($module) = @_;
    $module =~ s/\:\:/-/g;

    my %json_hash;
    my $base_url = "http://cpanratings.perl.org/dist/";
    my $url = $base_url . $module;
    my $response = $cacher->get( $url );
    my $content = $response->content;

    if ( $content =~ "$module reviews" )
    {
        %json_hash = populate_json_hash($content);
        #my $json = dump_json(\%json_hash);
        return %json_hash;
    }
    else
    {
        #print STDERR "404 Error with $module\n";
        return ();
    }

}

sub dump_all_ratings
{
    my $csv_file = '/tmp/all_ratings.csv';
    my $file     = Path::Class::File->new($csv_file);
    my $fh = $file->openw();
    $cacher->get('http://cpanratings.perl.org/csv/all_ratings.csv');

    print $fh $cacher->content;

    my $parser = Parse::CSV->new(
        file   => $csv_file,
        fields => 'auto',
    );

    my @to_insert = ();

    my $limit = 99999;
    my $i = 0;
    while ( my $rating = $parser->fetch ) {

        my $dist_name = $rating->{distribution};
        chomp($dist_name);
        if ( !defined( $dist_name ) ) { next; }

        $dbg && say "Trying |$dist_name| ....";
        my %fullratings = get_module_ratings($dist_name);
        next if keys %fullratings != 2
            and ( $dbg && say "Skipping |$dist_name|..." );

        $dbg && say "$dist_name: Avg Rating - " . $fullratings{avg_rating} ;
        my $data = {
            dist         => $rating->{distribution},
            rating       => $fullratings{avg_rating},
            reviews      => $fullratings{reviews},
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

        last if $i >= $limit;
        $i++;
    }

    #my $result = $es->bulk( \@to_insert );

    unlink $csv_file;
    return @to_insert;
}

sub populate_es
{
    my $csv_file = '/tmp/all_ratings.csv';
    my $file     = Path::Class::File->new($csv_file);
    my $fh = $file->openw();
    $cacher->get('http://cpanratings.perl.org/csv/all_ratings.csv');

    print $fh $cacher->content;

    my $parser = Parse::CSV->new(
        file   => $csv_file,
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

    #my $result = $es->bulk( \@to_insert );

    unlink $csv_file;
}

sub mean {
    return sum(@_)/@_;
}

#sub dump_full_html
#{
#    my $response = $cacher->get( $url );
#    my $content = $response->content;
#    my $p = HTML::TokeParser::Simple->new(\$content);
#    print "---- whole document ----\n";
#    while ( my $token = $p->get_token )
#    {
#        print $token->as_is; 
#    }
#    print "\n\n";
#}

sub dump_json
{
    my $hash_data = shift;
    my $coder = Cpanel::JSON::XS->new->ascii->pretty->allow_nonref;
    my $json = $coder->utf8->encode ($hash_data);
    #binmode(STDOUT, ":utf8");
    return $json;
}

sub prep_for_web
{
    if ( defined($ENV{'GATEWAY_INTERFACE'}) )
    {
        print "Content-type: text/html\n\n";
    }
}


sub populate_json_hash
{
    my ($content) = @_;
    my %json_hash;
    my @avg_rating;
    my $p = HTML::TokeParser::Simple->new(\$content);
    my $i = 0;
    while (my $token = $p->get_tag("h3"))
    {
        $token = $p->get_tag("a");  # <a> start tag
        $token = $p->get_token;     # Module name inside <a></a>
        $token = $p->get_token;     # </a> end tag 
        $token = $p->get_token;     # module version
        my $module_version = $token->[1];
        $module_version =~ s/\n//g;
        $module_version =~ s/.*\((.*)\).*/$1/;

        $token = $p->get_tag("img");
        my $rating = $token->[1]{'alt'} || "-";
        push @avg_rating, length($rating);

        $token = $p->get_tag("blockquote");
        my $review = $p->get_trimmed_text("/blockquote");

        $token = $p->get_tag("a");
        my $reviewer = $p->get_trimmed_text("/a");
        my $date = $p->get_trimmed_text("br");
        chomp($date);
        $date =~ s/(\d+-\d+-\d+)[[:space:]]+(\d+:\d+:\d+)/$1T$2/g;
        $date =~ s/(?:^-|[[:space:]]+)//g;

        $json_hash{'reviews'}{$i}{'rating'} = length($rating);
        $json_hash{'reviews'}{$i}{'review'} = $review;
        $json_hash{'reviews'}{$i}{'reviewer'} = $reviewer;
        $json_hash{'reviews'}{$i}{'review_date'} = $date;
        $json_hash{'reviews'}{$i}{'module_version'} = $module_version;

        $i++;
    }


    if ( defined($json_hash{'reviews'}) )
    {
        $json_hash{'avg_rating'} = sprintf( "%.2f", mean(@avg_rating) );
    }
    return %json_hash;
}
