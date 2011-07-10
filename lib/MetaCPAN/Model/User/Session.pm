package MetaCPAN::Model::User::Session;
use Moose;
use ElasticSearchX::Model::Document;
use DateTime;

has id => ( id => 1 );

has date =>
    ( required => 1, isa => 'DateTime', default => sub { DateTime->now } );

has account => ( parent => 1, is => 'rw' );

__PACKAGE__->meta->make_immutable;
