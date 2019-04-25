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
    my $target = $self->home->file(@path);
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

    my $bulk = $self->es->bulk_helper(
        index     => 'cpan',
        type      => 'rating',
        max_count => 500,
    );

    $self->delete_old_ratings($bulk);

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
    $self->refresh;
    log_info {'done'};
}

sub delete_old_ratings {
    my ( $self, $bulk ) = @_;

    log_debug {'Deleting old CPANRatings'};

    my $scroll = $self->es->scroll_helper(
        {
            size   => 1000,
            scroll => '1m',
            index  => 'cpan',
            type   => 'rating',
            fields => [],
        }
    );

    my @ids;

    while ( my $rating = $scroll->next ) {
        push @ids, $rating->{_id};
    }

    $bulk->delete_ids(@ids);
    $bulk->flush;
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
