package MetaCPAN::Document::Contributor::Set;

use Moose;

use MetaCPAN::Query::Contributor ();

extends 'ElasticSearchX::Model::Document::Set';

has query_contributor => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Contributor',
    lazy    => 1,
    builder => '_build_query_contributor',
    handles => [qw< find_author_contributions find_release_contributors >],
);

sub _build_query_contributor {
    my $self = shift;
    return MetaCPAN::Query::Contributor->new(
        es         => $self->es,
        index_name => 'contributor',
    );
}

__PACKAGE__->meta->make_immutable;
1;
