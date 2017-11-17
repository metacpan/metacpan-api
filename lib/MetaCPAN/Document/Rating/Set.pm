package MetaCPAN::Document::Rating::Set;

use Moose;

use MetaCPAN::Query::Rating;

extends 'ElasticSearchX::Model::Document::Set';

has query_rating => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Rating',
    lazy    => 1,
    builder => '_build_query_rating',
    handles => [qw< by_distributions >],
);

sub _build_query_rating {
    my $self = shift;
    return MetaCPAN::Query::Rating->new(
        es         => $self->es,
        index_name => $self->index->name,
    );
}

__PACKAGE__->meta->make_immutable;
1;
