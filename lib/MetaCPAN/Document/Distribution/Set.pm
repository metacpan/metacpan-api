package MetaCPAN::Document::Distribution::Set;

use Moose;

use MetaCPAN::Query::Distribution;

extends 'ElasticSearchX::Model::Document::Set';

has query_distribution => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Distribution',
    lazy    => 1,
    builder => '_build_query_distribution',
    handles => [qw< get_river_data_by_dist get_river_data_by_dists >],
);

sub _build_query_distribution {
    my $self = shift;
    return MetaCPAN::Query::Distribution->new(
        es         => $self->es,
        index_name => 'cpan',
    );
}

__PACKAGE__->meta->make_immutable;
1;
