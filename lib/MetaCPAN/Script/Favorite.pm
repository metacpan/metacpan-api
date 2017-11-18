package MetaCPAN::Script::Favorite;

use Moose;

use Log::Contextual qw( :log );

use MetaCPAN::Types qw( Int );

with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

=head1 SYNOPSIS

Updates the dist_fav_count field in 'file' by the count of ++ in 'favorite'

=cut

has age => (
    is  => 'ro',
    isa => Int,
    documentation =>
        'Update distributions that were voted on in the last X hours',
);

sub run {
    my $self = shift;
    $self->index_favorites;
    $self->index->refresh;
}

sub index_favorites {
    my $self = shift;
    my $age  = $self->age;

    log_info {"Start"};

    my %dist_fav_count;
    my %recent_dists;
    my $body;

    if ($age) {
        my $favs = $self->es->scroll_helper(
            index       => $self->index->name,
            type        => 'favorite',
            search_type => 'scan',
            scroll      => '5m',
            fields      => [qw< distribution >],
            size        => 500,
            body        => {
                query => {
                    range => { date => { gte => sprintf( 'now-%dh', $age ) } }
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

    my $favs = $self->es->scroll_helper(
        index       => $self->index->name,
        type        => 'favorite',
        search_type => 'scan',
        scroll      => '30s',
        fields      => [qw< distribution >],
        size        => 500,
        ( body => $body ) x !!$body,
    );

    while ( my $fav = $favs->next ) {
        my $dist = $fav->{fields}{distribution}[0];
        $dist_fav_count{$dist}++ if $dist;
    }

    log_info {"Done counting favs for all dists"};

    my $bulk = $self->es->bulk_helper(
        index     => $self->index->name,
        type      => 'file',
        max_count => 250,
        timeout   => '6000m',
    );

    for my $dist ( keys %dist_fav_count ) {
        log_info {"Dist $dist"};

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

            log_info {"Updating file id $id with fav_count $cnt"};

            $bulk->update(
                {
                    id  => $file->{fields}{id}[0],
                    doc => { dist_fav_count => $cnt },
                }
            );
        }
    }

    $bulk->flush;
}

__PACKAGE__->meta->make_immutable;
1;
