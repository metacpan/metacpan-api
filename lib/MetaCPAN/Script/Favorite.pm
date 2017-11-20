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

has check_missing => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
    documentation =>
        'Report distributions that are missing from "file" or queue jobs if "--queue" specified',
);

has age => (
    is  => 'ro',
    isa => Int,
    documentation =>
        'Update distributions that were voted on in the last X minutes',
);

has limit => (
    is            => 'ro',
    isa           => Int,
    documentation => 'Limit number of results',
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

    if ( $self->check_missing and $self->distribution ) {
        die
            "check_missing doesn't work in filtered mode - please remove other flags";
    }

    $self->index_favorites;
    $self->index->refresh;
}

sub index_favorites {
    my $self = shift;

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
                },
                ( $self->limit ? ( size => $self->limit ) : () )
            }
        );

        my %recent_dists;

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

    # Report missing distributions if requested

    if ( $self->check_missing ) {
        my %missing;

        my $files = $self->es->scroll_helper(
            index       => $self->index->name,
            type        => 'file',
            search_type => 'scan',
            scroll      => '15m',
            fields      => [qw< id distribution >],
            size        => 500,
            body        => {
                query => {
                    bool => {
                        must_not =>
                            { range => { dist_fav_count => { gte => 1 } } }
                    }
                }
            },
        );

        while ( my $file = $files->next ) {
            my $dist = $file->{fields}{distribution}[0];
            next unless $dist;
            next if exists $missing{$dist} or exists $dist_fav_count{$dist};

            if ( $self->queue ) {
                log_debug {"Queueing: $dist"};

                my @count_flag;
                if ( $self->count or $dist_fav_count{$dist} ) {
                    @count_flag = ( '--count',
                        $self->count || $dist_fav_count{$dist} );
                }

                $self->_add_to_queue( index_favorite =>
                        [ '--distribution', $dist, @count_flag ] =>
                        { priority => 0, attempts => 10 } );
            }
            else {
                log_debug {"Found missing: $dist"};
            }

            $missing{$dist} = 1;
            last if $self->limit and scalar( keys %missing ) >= $self->limit;
        }

        my $total_missing = scalar( keys %missing );
        log_debug {"Total missing: $total_missing"} unless $self->queue;

        return;
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
                ] => { priority => 0, attempts => 10 }
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
