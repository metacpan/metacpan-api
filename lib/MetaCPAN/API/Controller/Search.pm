package MetaCPAN::API::Controller::Search;

use Mojo::Base 'Mojolicious::Controller';

has model => sub { shift->app->model_search };

sub first {
    my $c = shift;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;

    my $results = $c->model->search_for_first_result( $args->{q} );
    return $c->render( openapi => $results ) if $results;
    $c->rendered(404);
}

sub web {
    my $c = shift;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;

    my @search = ( @{$args}{qw/q from size/} );
    push @search, $args->{collapsed} if exists $args->{collapsed};
    my $results = $c->model->search_web(@search);

    return $c->render( json => $results );
}

1;

