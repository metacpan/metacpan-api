package MetaCPAN::Server::Model::CPAN;

use Moose;

use MetaCPAN::Model          ();
use MetaCPAN::Server::Config ();

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

has index => (
    is      => 'ro',
    default => 'cpan',
);

sub type {
    my $self = shift;
    return $self->_esx_model->index( $self->index )->type(shift);
}

sub BUILD {
    my ( $self, $args ) = @_;
    my $index = $self->_esx_model->index( $self->index );
    my $class = ref $self;
    while ( my ( $k, $v ) = each %{ $index->types } ) {
        no strict 'refs';
        my $classname = "${class}::" . ucfirst($k);
        *{"${classname}::ACCEPT_CONTEXT"} = sub {
            return $index->type($k);
        };
    }
}

1;
