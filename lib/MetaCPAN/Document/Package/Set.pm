package MetaCPAN::Document::Package::Set;

use Moose;

use MetaCPAN::Query::Package;

extends 'ElasticSearchX::Model::Document::Set';

has query_package => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Package',
    lazy    => 1,
    builder => '_build_query_package',
    handles => [qw< get_modules >],
);

sub _build_query_package {
    my $self = shift;
    return MetaCPAN::Query::Package->new(
        es         => $self->es,
        index_name => $self->index->name,
    );
}

__PACKAGE__->meta->make_immutable;
1;
