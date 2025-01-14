package MetaCPAN::Server::Model::ESQuery;

use Moose;

use MetaCPAN::Query ();

extends 'Catalyst::Model';

has es => (
    is     => 'ro',
    writer => '_set_es',
);

has _esx_query => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        MetaCPAN::Query->new( es => $self->es );
    },
);

sub ACCEPT_CONTEXT {
    my ( $self, $c ) = @_;
    if ( !$self->es ) {
        $self->_set_es( $c->model('ES') );
    }
    return $self->_esx_query;
}

1;
