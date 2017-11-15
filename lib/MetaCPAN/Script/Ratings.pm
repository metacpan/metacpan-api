package MetaCPAN::Script::Ratings;

use strict;
use warnings;

use Digest::MD5    ();
use LWP::UserAgent ();
use Log::Contextual qw( :log :dlog );
use Moose;
use Parse::CSV ();

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has ratings => (
    is      => 'ro',
    default => 'http://cpanratings.perl.org/csv/all_ratings.csv'
);

sub run {
    my $self = shift;

    log_info { 'Downloading ' . $self->ratings };

    my @path   = qw( var tmp ratings.csv );
    my $target = $self->home->child(@path);
    my $md5    = -e $target ? $self->digest($target) : 0;
    my $res    = $self->ua->mirror( $self->ratings, $target );
    if ( $md5 eq $self->digest($target) ) {
        log_info {'No changes to ratings.csv'};
        return;
    }

    my $parser = Parse::CSV->new(
        file   => "$target",
        fields => 'auto',
    );

    my $type = $self->index->type('rating');
    log_debug {'Deleting old CPANRatings'};

    $type->filter( { term => { user => 'CPANRatings' } } )->delete;

    my $bulk = $self->es->bulk_helper(
        index     => $self->index->name,
        type      => 'rating',
        max_count => 500,
    );

    my $date = DateTime->now->iso8601;
    while ( my $rating = $parser->fetch ) {
        next unless ( $rating->{review_count} );
        my $data = {
            distribution => $rating->{distribution},
            release      => 'PLACEHOLDER',
            author       => 'PLACEHOLDER',
            rating       => $rating->{rating},
            user         => 'CPANRatings',
            date         => $date,
        };

        for ( my $i = 0; $i < $rating->{review_count}; $i++ ) {
            $bulk->create(
                {
                    source => Dlog_trace {$_} $data,
                }
            );
        }
    }
    $bulk->flush;
    $self->index->refresh;
    log_info {'done'};
}

sub digest {
    my ( $self, $file ) = @_;
    my $md5 = Digest::MD5->new;
    $md5->addfile( $file->openr );
    my ($digest) = Dlog_debug {"MD5 of file $file is $_"} $md5->hexdigest;
    return $digest;
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

 $ bin/metacpan ratings

=head1 SOURCE

L<http://cpanratings.perl.org/csv/all_ratings.csv>

=cut
