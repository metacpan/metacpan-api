package MetaCPAN::Document::Author::Set;
use Moose;
extends 'ElasticSearchX::Model::Document::Set';

sub authorsearch {
    my ( $self, $query ) = @_;
    return $self->query( { term => { 'author.name' => $query } } );

}

__PACKAGE__->meta->make_immutable;
1;
