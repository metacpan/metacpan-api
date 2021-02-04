package MetaCPAN::Document::Favorite::Set;

use Moose;

use MetaCPAN::Query::Favorite ();

extends 'ElasticSearchX::Model::Document::Set';

has query_favorite => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Favorite',
    lazy    => 1,
    builder => '_build_query_favorite',
    handles => [
        qw< agg_by_distributions
            by_user
            leaderboard
            recent
            users_by_distribution >
    ],
);

sub _build_query_favorite {
    my $self = shift;
    return MetaCPAN::Query::Favorite->new(
        es         => $self->es,
        index_name => $self->index->name,
    );
}

__PACKAGE__->meta->make_immutable;
1;
