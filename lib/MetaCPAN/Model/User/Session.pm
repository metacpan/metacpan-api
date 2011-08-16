package MetaCPAN::Model::User::Session;
use Moose;
use ElasticSearchX::Model::Document;
use DateTime;

has id => ( is => 'ro', id => 1 );

has date =>
    ( is => 'ro', required => 1, isa => 'DateTime', default => sub { DateTime->now } );

has account => ( parent => 1, is => 'rw', required => 1 );

__PACKAGE__->meta->make_immutable;
