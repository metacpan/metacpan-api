package MetaCPAN::Server::Model::ES;

use Moose;

use MetaCPAN::Server::Config  ();
use MetaCPAN::Types::TypeTiny qw( ES );

extends 'Catalyst::Model';

has es => (
    is      => 'ro',
    isa     => ES,
    coerce  => 1,
    lazy    => 1,
    default => sub {
        MetaCPAN::Server::Config::config()->{elasticsearch_servers};
    },
);

sub ACCEPT_CONTEXT {
    my ( $self, $c ) = @_;
    return $self->es;
}

1;
