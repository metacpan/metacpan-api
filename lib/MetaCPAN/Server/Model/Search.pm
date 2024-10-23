package MetaCPAN::Server::Model::Search;

use strict;
use warnings;

use Moose;
use MetaCPAN::Query::Search ();

extends 'MetaCPAN::Server::Model::CPAN';

has search => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Search',
    lazy    => 1,
    handles => [qw( search_for_first_result search_web )],
    default => sub {
        my $self = shift;
        return MetaCPAN::Query::Search->new( es => $self->es, );
    },
);

1;

