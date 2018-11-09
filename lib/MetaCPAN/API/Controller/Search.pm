package MetaCPAN::API::Controller::Search;

use Mojo::Base 'Mojolicious::Controller';

sub web {
    my $c = shift;
    return unless $c->openapi->valid_input;
    my $args = $c->validation->output;

    my @search = ( @{$args}{qw/q from size/} );
    push @search, $args->{collapsed} if exists $args->{collapsed};
    my $results = $c->app->model_search->search_web(@search);

    #TODO once output validation works, use this line instead of the one after
    #return $c->render(openapi => $results);
    return $c->render( json => $results );
}

sub first {

}

1;

