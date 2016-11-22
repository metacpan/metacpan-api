package MetaCPAN::Server::Model::Search;

use strict;
use warnings;

use Moose;
use MetaCPAN::Model::Search;

extends 'MetaCPAN::Server::Model::CPAN';

has search => (
    is      => 'ro',
    isa     => 'MetaCPAN::Model::Search',
    lazy    => 1,
    handles => [qw( search_simple search_web )],
    default => sub {
        my $self = shift;
        return MetaCPAN::Model::Search->new(
            es    => $self->es,
            index => $self->index,
        );
    },
);

1;

