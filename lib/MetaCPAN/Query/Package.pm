package MetaCPAN::Query::Package;

use Moose;

with 'MetaCPAN::Query::Role::Common';

sub get_modules {
    my ( $self, $dist, $ver ) = @_;

    my $query = +{
        query => {
            bool => {
                must => [
                    { term => { distribution => $dist } },
                    { term => { dist_version => $ver } },
                ],
            }
        }
    };

    my $res = $self->es->search(
        index => $self->index_name,
        type  => 'package',
        body  => {
            query   => $query,
            size    => 999,
            _source => [qw< module_name >],
        }
    );

    my $hits = $res->{hits}{hits};
    return [] unless @{$hits};
    return +{ modules => [ map { $_->{_source}{module_name} } @{$hits} ] };
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
