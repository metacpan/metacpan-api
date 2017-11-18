package MetaCPAN::Query::Rating;

use MetaCPAN::Moose;

with 'MetaCPAN::Query::Role::Common';

sub by_distributions {
    my ( $self, $distributions ) = @_;

    my $body = {
        size         => 0,
        query        => { terms => { distribution => $distributions } },
        aggregations => {
            ratings => {
                terms => {
                    field => 'distribution'
                },
                aggregations => {
                    ratings_dist => {
                        stats => {
                            field => 'rating'
                        }
                    }
                }
            }
        }
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'rating',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my %distributions = map { $_->{key} => $_->{ratings_dist} }
        @{ $ret->{aggregations}{ratings}{buckets} };

    return {
        distributions => \%distributions,
        total         => $ret->{hits}{total},
        took          => $ret->{took}
    };
}

__PACKAGE__->meta->make_immutable;
1;
