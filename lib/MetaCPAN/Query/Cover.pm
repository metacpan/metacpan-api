package MetaCPAN::Query::Cover;

use MetaCPAN::Moose;

with 'MetaCPAN::Query::Role::Common';

sub find_release_coverage {
    my ( $self, $release ) = @_;

    my $query = +{ term => { release => $release } };

    my $res = $self->es->search(
        index => $self->index_name,
        type  => 'cover',
        body  => {
            query => $query,
            size  => 999,
        }
    );
    $res->{hits}{total} or return {};

    return $res->{hits}{hits}[0]{_source};
}

__PACKAGE__->meta->make_immutable;
1;
