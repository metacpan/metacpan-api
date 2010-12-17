#!/usr/bin/env perl

use Modern::Perl;
use Data::Dump qw( dump );
use Every;
use Find::Lib '../lib';
use MetaCPAN;
use MetaCPAN::Dist;
use Time::HiRes qw( gettimeofday tv_interval );

my $t_begin = [gettimeofday];

my $attempts = 0;
my $every    = 20;
my $cpan     = MetaCPAN->new_with_options;
$cpan->check_db;

$cpan->debug( $ENV{'DEBUG'} );

my @dists = ();

my $total_dists = 1;
say $cpan->dist_name;

if ( $cpan->dist_like ) {
    say "searching for dists like: " . $cpan->dist_like;
    @dists = search_dists( { dist => { like => $cpan->dist_like, '!=' => undef, } } );
}

elsif ( $cpan->dist_name ) {
    say "searching for dist: " . $cpan->dist_name;
    @dists = search_dists( { dist => $cpan->dist_name } );
}

else {
    say "search all dists";
    @dists = search_dists();
}
say dump( \@dists);
foreach my $dist ( @dists ) {
    process_dist( $dist );
}

my $t_elapsed = tv_interval( $t_begin, [gettimeofday] );
say "Entire process took $t_elapsed";

sub process_dist {

    my $distvname = shift;
    my $t0        = [gettimeofday];

    say '+' x 20 . " DIST: $distvname" if $cpan->debug;

    my $dist = MetaCPAN::Dist->new( distvname => $distvname, module_rs => $cpan->module_rs );
    $dist->process;

    say "Found " . scalar @{ $dist->processed } . " modules in dist";
    $dist->tar->clear if $dist->tar;
    $dist = undef;
    
    ++$attempts;
    
    # diagnostics
    if ( every( $every ) ) {

        my $iter_time = tv_interval( $t0,      [gettimeofday] );
        my $elapsed   = tv_interval( $t_begin, [gettimeofday] );
        say '#' x 78;
    
        say "$distvname";    # if $icpan->debug;
        say "$iter_time to process dist";
        say "$elapsed so far... ($attempts dists out of $total_dists)";

        my $seconds_per_dist = $elapsed / $attempts;
        say "average $seconds_per_dist per dist";

        my $total_duration = $seconds_per_dist * $total_dists;
        my $total_hours    = $total_duration / 3600;
        say "estimated total time: $total_duration ($total_hours hours)";
        say '#' x 78;

    }


    return;

}

sub search_dists {

    my $constraints = shift || {};

    my $search = $cpan->module_rs->search(
        $constraints,
        {   +select  => 'distvname',
            columns  => ['dist'],
            distinct => 1,
            order_by => 'distvname DESC',
            rows     => 1
        }
    );

    my @dists = ();
    while ( my $row = $search->next ) {
        push @dists, $row->distvname;
    }

    say "found $total_dists distros";

    return @dists;

}

