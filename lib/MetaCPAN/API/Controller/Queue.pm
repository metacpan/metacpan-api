package MetaCPAN::API::Controller::Queue;

use Mojo::Base 'Mojolicious::Controller';

my $rel
    = 'https://cpan.metacpan.org/authors/id/O/OA/OALDERS/HTML-Restrict-2.2.2.tar.gz';

sub enqueue {
    my $self = shift;
    $self->minion->enqueue( index_release => [ '--latest', $rel ] );
    $self->render( text => 'OK' );
}

sub index_release {
    my $self = shift;
    $self->render( text => 'ok' );
}

1;
