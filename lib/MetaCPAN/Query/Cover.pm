package MetaCPAN::Query::Cover;

use MetaCPAN::Moose;

use MetaCPAN::Util qw(hit_total);

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
    hit_total($res) or return {};

    return +{
        %{ $res->{hits}{hits}[0]{_source} },
        url => "http://cpancover.com/latest/$release/index.html",
    };
}

__PACKAGE__->meta->make_immutable;
1;
