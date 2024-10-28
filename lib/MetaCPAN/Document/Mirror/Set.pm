package MetaCPAN::Document::Mirror::Set;

use Moose;

use MetaCPAN::Query::Mirror ();

extends 'ElasticSearchX::Model::Document::Set';

has query_mirror => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Mirror',
    lazy    => 1,
    builder => '_build_query_mirror',
    handles => [qw< search >],
);

sub _build_query_mirror {
    my $self = shift;
    return MetaCPAN::Query::Mirror->new( es => $self->es );
}

__PACKAGE__->meta->make_immutable;
1;
