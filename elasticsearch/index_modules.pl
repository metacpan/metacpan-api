#!/usr/bin/perl

=head1 SYNOPSIS

Loads author info into db.  Requires the presence of a local CPAN/minicpan.

    perl index_modules.pl /path/to/(mini)cpan

=cut

use Modern::Perl;

use Data::Dump qw( dump );
use DateTime::Format::Epoch::Unix;
use Every;
use Find::Lib '../lib', '../../iCPAN/perl/lib';
use iCPAN;
use MetaCPAN;

my $cpan = shift @ARGV || "$ENV{'HOME'}/minicpan";

if ( !-d $cpan ) {
    die "Usage: perl index_modules.pl /path/to/(mini)cpan";
}

my $icpan = iCPAN->new;
$icpan->db_file( Find::Lib::base() . '/../../iCPAN/iCPAN.sqlite' );
my $every    = 100;
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
        index_pod( \@to_insert );
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
            pauseid      => { type => "string" },
            dist         => { type => "string" },
            distvname    => { type => "string" },
            download_url => { type => "string" },
            name         => { type => "string" },
            release_date => { type => "date" },
            version      => { type => "string" },
        }
    );

}

sub index_pod {

    my $to_insert = shift;

    my %dists   = ();
    my @modules = ();
    foreach my $row ( @{$to_insert} ) {
        say dump $row;
        my $data = $row->{index}->{data};
        push @modules, $data->{name};
        $dists{ $data->{dist} } = 1;
    }
    
    my $dist_list = join " ", sort keys %dists;
    my $load = `perl /home/olaf/iCPAN/perl/script/load_dists.pl $dist_list`;
    say $load;

    my @inserts = ();
    my $module_rs
        = $icpan->schema->resultset( 'iCPAN::Schema::Result::Zmodule' )
        ->search( { zname => \@modules, zpod => { '!=' => undef } }, {} );
        
    while ( my $module = $module_rs->next ) {
        my %es_insert = (
            index => {
                index => 'cpan',
                type  => 'pod',
                id    => $module->zname,
                data  => { pod => $module->zpod },
            }
        );

        push @inserts, \%es_insert;
    }

    my $result = $es->bulk( \@inserts );

    say dump $result;

}
