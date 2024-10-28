package MetaCPAN::Document::Permission::Set;

use Moose;

use MetaCPAN::Query::Permission ();

extends 'ElasticSearchX::Model::Document::Set';

has query_permission => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Permission',
    lazy    => 1,
    builder => '_build_query_permission',
    handles => [qw< by_author by_modules >],
);

sub _build_query_permission {
    my $self = shift;
    return MetaCPAN::Query::Permission->new( es => $self->es );
}

__PACKAGE__->meta->make_immutable;
1;
