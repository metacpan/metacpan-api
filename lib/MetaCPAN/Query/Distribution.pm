package MetaCPAN::Query::Distribution;

use MetaCPAN::Moose;

with 'MetaCPAN::Query::Role::Common';

sub get_river_data_by_dist {
    my ( $self, $dist ) = @_;

    my $query = +{
        bool => {
            must => [ { term => { name => $dist } }, ]
        }
    };

    my $res = $self->es->search(
        index => $self->index_name,
        type  => 'distribution',
        body  => {
            query => $query,
            size  => 999,
        }
    );
    $res->{hits}{total} or return {};

    return +{ river => +{ $dist => $res->{hits}{hits}[0]{_source}{river} } };
}

sub get_river_data_by_dists {
    my ( $self, $dist ) = @_;

    my $query = +{
        bool => {
            must => [ { terms => { name => $dist } }, ]
        }
    };

    my $res = $self->es->search(
        index => $self->index_name,
        type  => 'distribution',
        body  => {
            query => $query,
            size  => 999,
        }
    );
    $res->{hits}{total} or return {};

    return +{
        river => +{
            map { $_->{_source}{name} => $_->{_source}{river} }
                @{ $res->{hits}{hits} }
        },
    };
}

__PACKAGE__->meta->make_immutable;
1;
