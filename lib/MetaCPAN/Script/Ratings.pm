package MetaCPAN::Script::Ratings;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log :dlog );
with 'MetaCPAN::Role::Common';
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use JSON           ();
use Parse::CSV     ();
use LWP::UserAgent ();

has ratings =>
  ( is => 'ro', default => 'http://cpanratings.perl.org/csv/all_ratings.csv' );

sub run {
    my $self = shift;
    $self->index_ratings;
    $self->index->refresh;
}

sub index_ratings {
    my $self = shift;
    my $ua   = LWP::UserAgent->new;
    log_info { "Downloading " . $self->ratings };
    my $target = catfile( tempdir( CLEANUP => 1 ), 'ratings.csv' );
    $ua->mirror( $self->ratings, $target );

    my $parser = Parse::CSV->new(
        file   => $target,
        fields => 'auto', );

    my $type = $self->index->type('rating');
    while ( my $rating = $parser->fetch ) {
        next unless ( $rating->{review_count} );
        my $data = {
            distribution => $rating->{distribution},
            release      => 'PLACEHOLDER',
            author       => 'PLACEHOLDER',
            rating       => $rating->{rating},
            user         => 'CPANRatings' };
        for ( my $i = 0 ; $i < $rating->{review_count} ; $i++ ) {
            $type->put( Dlog_trace { $_ } $data );
        }
    }
    log_info { "done" };
}

1;

=pod

=head1 SYNOPSIS

 $ bin/metacpan mirrors

=head1 SOURCE

L<http://www.cpan.org/indices/mirrors.json>

=cut
