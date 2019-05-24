package MetaCPAN::API::Controller::Cover;

use Mojo::Base 'Mojolicious::Controller';

sub lookup {
    my $c = shift;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;

    my $results = $c->model->cover->find_release_coverage( $args->{name} );
    return $c->render( openapi => $results ) if $results;
    $c->rendered(404);
}

1;

