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
#      COMPANY:  VMware Inc.
#      VERSION:  1.0
#      CREATED:  11/11/10 05:01:10 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use Data::Dumper;
use Data::Dump;

use List::Util qw(sum);
use WWW::Mechanize::Cached;
use HTML::TokeParser::Simple;
use JSON::XS;


# Incoming arg = module name (e.g., Data::Dumper)
# would pull info from http://cpanratings.perl.org/dist/Data-Dumper
my $module = shift or die "Need a CPAN module as a script argument!\n";
   $module =~ s/\:\:/-/g;

my $base_url = "http://cpanratings.perl.org/dist/";
my $url = "http://cpanratings.perl.org/dist/". $module;
my $cacher = WWW::Mechanize::Cached->new;
my $response = $cacher->get( $url );
my $content = $response->content;

my @avg_rating;
my %json_hash;


prep_for_web();
if ( $content !~ "<h3>404 - File not found</h3>" )
{
    #dump_full_html(); # For testing - cleans up the HTML a bit before output
    populate_json_hash();
    dump_json(\%json_hash);

    #print Dumper(\%ENV);
}
else
{
    print "404 Error\n";
}




#DONE

#____________________________________________SUBROUTINES______
sub mean {
    return sum(@_)/@_;
}

sub dump_full_html
{
    my $p = HTML::TokeParser::Simple->new(\$content);
    print "---- whole document ----\n";
    while ( my $token = $p->get_token )
    {
        print $token->as_is; 
    }
    print "\n\n";
}

sub dump_json
{
    my $hash_data = shift;
    my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
    my $json = $coder->utf8->encode ($hash_data);
    #binmode(STDOUT, ":utf8");
    print STDOUT $json;
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
}
