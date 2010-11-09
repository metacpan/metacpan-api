#!/usr/bin/perl

=head1 SYNOPSIS

Loads author info into db.  Requires the presence of a local CPAN/minicpan.

    perl index_modules.pl /path/to/(mini)cpan

=cut

use Modern::Perl;

use Data::Dump qw( dump );
use DateTime::Format::Epoch::Unix;
use Every;
use Find::Lib '../lib';
use MetaCPAN;

my $cpan = shift @ARGV || "$ENV{'HOME'}/minicpan";
if ( !-d $cpan ) {
    die "Usage: perl index_modules.pl /path/to/(mini)cpan";
}

my $metacpan = MetaCPAN->new( cpan => $cpan );
my $es = $metacpan->es;

my $pkgs      = $metacpan->pkg_index;
my @to_insert = ();

foreach my $module_name ( sort keys %{$pkgs} ) {
    my $module = $pkgs->{$module_name};
    $module->{name} = $module_name;
    $module->{download_url}
        = 'http://cpan.metacpan.org/authors/id/' . $module->{archive};

    # get datestamp
    my $dist_file = '/home/cpan/CPAN/authors/id/' . $module->{archive};
    my $date      = ( stat( $dist_file ) )[9];
    my $dt        = DateTime::Format::Epoch::Unix->parse_datetime( $date );
    $module->{release_date} = $dt->ymd . ' ' . $dt->hms;

    my %es_insert = (
        index => {
            index => 'cpan',
            type  => 'module',
            id    => $module_name,
            data  => $module
        }
    );

    push @to_insert, \%es_insert;

    if ( every( 500 ) ) {
        my $result = $es->bulk( \@to_insert );
        @to_insert = ();
    }

    # the slow way
    #$es->index( %es_insert );

    say $module_name;

}

