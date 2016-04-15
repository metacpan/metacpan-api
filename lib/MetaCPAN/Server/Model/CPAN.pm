package MetaCPAN::Server::Model::CPAN;

use strict;
use warnings;

use MetaCPAN::Model;
use Moose;

extends 'Catalyst::Model';

with 'CatalystX::Component::Traits';

has esx_model => (
    is      => 'ro',
    handles => ['es'],
    default => sub { MetaCPAN::Model->new( es => $_[0]->servers ) },
);

has index => (
    is      => 'ro',
    default => 'cpan',
);

has servers => (
    is      => 'ro',
    default => ':9200',
);

sub type {
    my $self = shift;
    return $self->esx_model->index( $self->index )->type(shift);
}

sub BUILD {
    my ( $self, $args ) = @_;
    my $index = $self->esx_model->index( $self->index );
    my $class = $self->_original_class_name;
    while ( my ( $k, $v ) = each %{ $index->types } ) {
        no strict 'refs';
        my $classname = "${class}::" . ucfirst($k);
        *{"${classname}::ACCEPT_CONTEXT"} = sub {
            return $index->type($k);
        };
    }
}

1;
