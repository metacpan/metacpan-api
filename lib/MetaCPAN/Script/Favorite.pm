package MetaCPAN::Script::Favorite;

use Moose;

use Log::Contextual qw( :log );

use MetaCPAN::Types qw( Bool Int Str );

with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

=head1 SYNOPSIS

Updates the dist_fav_count field in 'file' by the count of ++ in 'favorite'

=cut

has queue => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'Use the queue for updates',
);

has age => (
    is  => 'ro',
    isa => Int,
    documentation =>
        'Update distributions that were voted on in the last X minutes',
);

has distribution => (
    is            => 'ro',
    isa           => Str,
    documentation => 'Update only a given distribution',
);

has count => (
    is  => 'ro',
    isa => Int,
    documentation =>
        'Update this count to a given distribution (will only work with "--distribution"',
);

sub run {
    my $self = shift;

    if ( $self->count and !$self->distribution ) {
        die
            "Cannot set count in a distribution search mode, this flag only applies to a single distribution. please use together with --distribution DIST";
    }

    $self->index_favorites;
    $self->index->refresh;
}

sub index_favorites {
    my $self = shift;

    my %recent_dists;
    my $body;

    if ( $self->distribution ) {
        $body = {
            query => {
                term => { distribution => $self->distribution }
            }
        };

    }
    elsif ( $self->age ) {
        my $favs = $self->es->scroll_helper(
            index       => $self->index->name,
            type        => 'favorite',
            search_type => 'scan',
            scroll      => '5m',
            fields      => [qw< distribution >],
            size        => 500,
            body        => {
                query => {
                    range => {
                        date => { gte => sprintf( 'now-%dm', $self->age ) }
                    }
                }
            }
        );

        while ( my $fav = $favs->next ) {
            my $dist = $fav->{fields}{distribution}[0];
            $recent_dists{$dist}++ if $dist;
        }

        my @keys = keys %recent_dists;
        if (@keys) {
            $body = {
                query => {
                    terms => { distribution => \@keys }
                }
            };
        }
    }

    # get total fav counts for distributions

    my %dist_fav_count;

    if ( $self->count ) {
        $dist_fav_count{ $self->distribution } = $self->count;
    }
    else {
        my $favs = $self->es->scroll_helper(
            index       => $self->index->name,
            type        => 'favorite',
            search_type => 'scan',
            scroll      => '30s',
            fields      => [qw< distribution >],
            size        => 500,
            ( $body ? ( body => $body ) : () ),
        );

        while ( my $fav = $favs->next ) {
            my $dist = $fav->{fields}{distribution}[0];
            $dist_fav_count{$dist}++ if $dist;
        }

        log_debug {"Done counting favs for distributions"};
    }

    # Update fav counts for files per distributions

    for my $dist ( keys %dist_fav_count ) {
        log_debug {"Dist $dist"};

        if ( $self->queue ) {
            $self->_add_to_queue(
                index_favorite => [
                    '--distribution',
                    $dist,
                    '--count',
                    ( $self->count ? $self->count : $dist_fav_count{$dist} )
                ] => { priority => 0 }
            );

        }
        else {
            my $bulk = $self->es->bulk_helper(
                index     => $self->index->name,
                type      => 'file',
                max_count => 250,
                timeout   => '120m',
            );

            my $files = $self->es->scroll_helper(
                index       => $self->index->name,
                type        => 'file',
                search_type => 'scan',
                scroll      => '15s',
                fields      => [qw< id >],
                size        => 500,
                body        => {
                    query => { term => { distribution => $dist } }
                },
            );

            while ( my $file = $files->next ) {
                my $id  = $file->{fields}{id}[0];
                my $cnt = $dist_fav_count{$dist};

                log_debug {"Updating file id $id with fav_count $cnt"};

                $bulk->update(
                    {
                        id  => $file->{fields}{id}[0],
                        doc => { dist_fav_count => $cnt },
                    }
                );
            }

            $bulk->flush;
        }
    }
}

__PACKAGE__->meta->make_immutable;
1;
