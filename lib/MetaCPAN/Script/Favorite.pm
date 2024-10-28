package MetaCPAN::Script::Favorite;

use Moose;

use Log::Contextual qw( :log );

use MetaCPAN::ESConfig        qw( es_doc_path );
use MetaCPAN::Types::TypeTiny qw( Bool Int Str );
use MetaCPAN::Util            qw( true false );

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
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation =>
        'Report distributions that are missing from "file" or queue jobs if "--queue" specified',
);

has age => (
    is            => 'ro',
    isa           => Int,
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
    is            => 'ro',
    isa           => Int,
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
    $self->es->indices->refresh;
}

sub index_favorites {
    my $self = shift;

    my $query = { match_all => {} };
    my $age_filter;
    if ( $self->age ) {
        $age_filter = {
            range => {
                date => { gte => sprintf( 'now-%dm', $self->age ) }
            }
        };
    }

    if ( $self->distribution ) {
        $query = { term => { distribution => $self->distribution } };

    }
    elsif ( $self->age ) {
        my $favs = $self->es->scroll_helper(
            es_doc_path('favorite'),
            scroll => '5m',
            body   => {
                query   => $age_filter,
                _source => [qw< distribution >],
                size    => $self->limit || 500,
                sort    => '_doc',
            }
        );

        my %recent_dists;

        while ( my $fav = $favs->next ) {
            my $dist = $fav->{_source}{distribution};
            $recent_dists{$dist}++ if $dist;
        }

        my @keys = keys %recent_dists;
        if (@keys) {
            $query = { terms => { distribution => \@keys } };
        }
    }

    # get total fav counts for distributions

    my %dist_fav_count;

    if ( $self->count ) {
        $dist_fav_count{ $self->distribution } = $self->count;
    }
    else {
        my $favs = $self->es->scroll_helper(
            es_doc_path('favorite'),
            scroll => '30s',
            body   => {
                query   => $query,
                _source => [qw< distribution >],
                size    => 500,
                sort    => '_doc',
            },
        );

        while ( my $fav = $favs->next ) {
            my $dist = $fav->{_source}{distribution};
            $dist_fav_count{$dist}++ if $dist;
        }

        log_debug {"Done counting favs for distributions"};
    }

    # Report missing distributions if requested

    if ( $self->check_missing ) {
        my %missing;
        my @age_filter;
        if ( $self->age ) {
            @age_filter = ( must => [$age_filter] );
        }

        my $files = $self->es->scroll_helper(
            es_doc_path('file'),
            scroll => '15m',
            body   => {
                query => {
                    bool => {
                        must_not => [
                            { range => { dist_fav_count => { gte => 1 } } }
                        ],
                        @age_filter,
                    }
                },
                _source => [qw< distribution >],
                size    => 500,
                sort    => '_doc',
            },
        );

        while ( my $file = $files->next ) {
            my $dist = $file->{_source}{distribution};
            next unless $dist;
            next if exists $missing{$dist} or exists $dist_fav_count{$dist};

            if ( $self->queue ) {
                log_debug {"Queueing: $dist"};

                my @count_flag;
                if ( $self->count or $dist_fav_count{$dist} ) {
                    @count_flag = (
                        '--count', $self->count || $dist_fav_count{$dist}
                    );
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
                es_doc_path('file'),
                max_count => 250,
                timeout   => '120m',
            );

            my $files = $self->es->scroll_helper(
                es_doc_path('file'),
                scroll => '15s',
                body   => {
                    query   => { term => { distribution => $dist } },
                    _source => false,
                    size    => 500,
                    sort    => '_doc',
                },
            );

            while ( my $file = $files->next ) {
                my $id  = $file->{_id};
                my $cnt = $dist_fav_count{$dist};

                log_debug {"Updating file id $id with fav_count $cnt"};

                $bulk->update( {
                    id  => $file->{_id},
                    doc => { dist_fav_count => $cnt },
                } );
            }

            $bulk->flush;
        }
    }
}

__PACKAGE__->meta->make_immutable;
1;
