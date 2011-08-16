package MetaCPAN::Model::User::Identity;
use Moose;
use ElasticSearchX::Model::Document;

has name => ( is => 'ro', required => 1 );

has key => ( is => 'ro' );

has extra => ( is => 'ro', isa => 'HashRef', source_only => 1, dynamic => 1 );

__PACKAGE__->meta->make_immutable;
