package MetaCPAN::Server::Controller::Root;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }

__PACKAGE__->config( namespace => '' );

sub default : Path {
    my ( $self, $c ) = @_;
    $c->forward('/not_found');
}

sub not_found : Private {
    my ( $self, $c ) = @_;
    $c->stash( { message => 'Not found' } );
    $c->response->status(404);
}

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    if ( $c->controller->enable_jsonp ) {

        # call default view unless body has been set
        $c->forward( $c->view ) unless ( $c->res->body );
        $c->forward( $c->view('JSONP') );
        $c->res->content_type('text/javascript')
            if ( $c->req->params->{callback} );
    }
}

1;
