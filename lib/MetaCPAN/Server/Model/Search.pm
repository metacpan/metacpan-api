package MetaCPAN::Server::Model::Search;

use strict;
use warnings;

use Moose;
use MetaCPAN::Query::Search ();

extends 'Catalyst::Model';

has es => (
    is     => 'ro',
    writer => '_set_es',
);

has search => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Search',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return MetaCPAN::Query::Search->new( es => $self->es );
    },
);

sub ACCEPT_CONTEXT {
    my ( $self, $c ) = @_;
    if ( !$self->es ) {
        $self->_set_es( $c->model('ESModel')->es );
    }
    return $self->search;
}

1;
