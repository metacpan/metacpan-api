package MetaCPAN::Document::Distribution;

use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw(BugSummary);
use MooseX::Types::Moose qw(ArrayRef);
use namespace::autoclean;

has name => ( is => 'ro', required => 1, id => 1 );
has bugs => (
    is      => 'rw',
    isa     => BugSummary,
    dynamic => 1,
);

__PACKAGE__->meta->make_immutable;

1;
