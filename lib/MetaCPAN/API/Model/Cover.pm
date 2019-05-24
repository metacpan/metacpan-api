package MetaCPAN::API::Model::Cover;

use MetaCPAN::Moose;

with 'MetaCPAN::API::Model::Role::ES';

sub find_release_coverage {
    my ( $self, $release ) = @_;

    my $query = +{ term => { release => $release } };

    my $res = $self->_run_query(
        index => 'cover',
        type  => 'cover',
        body  => {
            query => $query,
            size  => 999,
        }
    );
    $res->{hits}{total} or return {};

    return +{
        %{ $res->{hits}{hits}[0]{_source} },
        url => "http://cpancover.com/latest/$release/index.html",
    };
}

__PACKAGE__->meta->make_immutable;

1;

