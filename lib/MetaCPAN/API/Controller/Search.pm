package MetaCPAN::API::Controller::Search;

use Mojo::Base 'Mojolicious::Controller';

sub first {
    my $c = shift;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;

    my $results = $c->model->search->search_for_first_result( $args->{q} );
    return $c->render( openapi => $results ) if $results;
    $c->rendered(404);
}

sub web {
    my $c = shift;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;

    my $query = $args->{q};
    my $size  = $args->{page_size} // $args->{size} // 20;
    my $page = $args->{page} // ( 1 + int( ( $args->{from} // 0 ) / $size ) );
    my $collapsed = $args->{collapsed};

    my $results
        = $c->model->search->search_web( $query, $page, $size, $collapsed );

    return $c->render( json => $results );
}

1;

