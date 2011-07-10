package MetaCPAN::Model::User::Identity;
use Moose;
use ElasticSearchX::Model::Document;

has name => ();

has key => ( required => 0 );

has extra =>
    ( isa => 'HashRef', source_only => 1, dynamic => 1, required => 0 );

__PACKAGE__->meta->make_immutable;
