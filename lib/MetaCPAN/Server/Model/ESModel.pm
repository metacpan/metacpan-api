package MetaCPAN::Server::Model::ESModel;

use Moose;

use MetaCPAN::Model ();

extends 'Catalyst::Model';

has es => (
    is     => 'ro',
    writer => '_set_es',
);

has _esx_model => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        MetaCPAN::Model->new( es => $self->es );
    },
);

sub ACCEPT_CONTEXT {
    my ( $self, $c ) = @_;
    if ( !$self->es ) {
        $self->_set_es( $c->model('ES') );
    }
    return $self->_esx_model;
}

1;
