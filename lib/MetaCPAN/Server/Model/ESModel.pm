package MetaCPAN::Server::Model::ESModel;

use Moose;

use MetaCPAN::Model          ();
use MetaCPAN::Server::Config ();
use MetaCPAN::ESConfig       qw( es_config );

extends 'Catalyst::Model';

has _esx_model => (
    is      => 'ro',
    lazy    => 1,
    handles => ['es'],
    default => sub {
        MetaCPAN::Model->new(
            es => MetaCPAN::Server::Config::config()->{elasticsearch_servers}
        );
    },
);

sub ACCEPT_CONTEXT {
    my ( $self, $c ) = @_;
    return $self->_esx_model;
}

1;
