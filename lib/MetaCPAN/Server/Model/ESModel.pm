package MetaCPAN::Server::Model::ESModel;

use Moose;

use MetaCPAN::Model            ();
use MetaCPAN::Model::ESWrapper ();

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
        my $es   = MetaCPAN::Model::ESWrapper->new( $self->es );
        MetaCPAN::Model->new( es => $es );
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
