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

my $every    = 1000;
my $metacpan = MetaCPAN->new( cpan => $cpan );
my $es       = $metacpan->es;

my $pkgs      = $metacpan->pkg_index;
my @to_insert = ();
#put_mapping();

foreach my $module_name ( sort keys %{$pkgs} ) {
    my $module = $pkgs->{$module_name};
    $module->{name} = $module_name;
    $module->{download_url}
        = 'http://cpan.metacpan.org/authors/id/' . $module->{archive};

    $module->{release_date} = datestamp( $module );

    my %es_insert = (
        index => {
            index => 'cpan',
            type  => 'module',
            id    => $module_name,
            data  => $module
        }
    );

    push @to_insert, \%es_insert;

    if ( every( $every ) ) {
        my $result = $es->bulk( \@to_insert );
#        say dump( $result );
#        exit;
        @to_insert = ();
    }

    say $module_name;

}

sub datestamp {

    my $module    = shift;
    my $dist_file = '/home/cpan/CPAN/authors/id/' . $module->{archive};
    my $date      = ( stat( $dist_file ) )[9];
    return DateTime::Format::Epoch::Unix->parse_datetime( $date )->iso8601;

}

sub put_mapping {

    $es->delete_mapping(
        index => ['cpan'],
        type  => 'module',
    );

    my $result = $es->put_mapping(
        index => ['cpan'],
        type  => 'module',

        #_source => { compress => 1 },
        properties => {
            archive      => { type => "string" },
            author       => { type => "string" },
            dist         => { type => "string" },
            distvname    => { type => "string" },
            download_url => { type => "string" },
            name         => { type => "string" },
            release_date => { type => "date" },
            version      => { type => "string" },
        }
    );

}
