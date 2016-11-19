package MetaCPAN::Server::Controller::Root;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

__PACKAGE__->config( namespace => '' );

# This will catch anything that isn't matched by another route.
sub default : Path {
    my ( $self, $c ) = @_;
    $c->forward( '/not_found', [] );
}

# handle /
sub all : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->res->redirect(
        'https://github.com/metacpan/metacpan-api/blob/master/docs/API-docs.md',
        302
    );
}

# The parent class has a sub with this signature but expects a namespace
# and an es type... since this controller doesn't have those, just overwrite.
sub get : Path('') : Args(1) {
    my ( $self, $c ) = @_;
    $c->forward( '/not_found', [] );
}

sub not_found : Private {
    my ( $self, $c, @params ) = @_;
    my $message = join( '/', @params );

    # XXX fix me
    #    $c->clear_stash;
    $c->stash( { code => 404, message => $message || "Not found" } );
    $c->response->status(404);
    $c->forward( $c->view('JSON') );
}

sub not_allowed : Private {
    my ( $self, $c, $message ) = @_;

    # XXX fix me
    #    $c->clear_stash;
    $c->stash( { message => $message || 'Not allowed' } );
    $c->response->status(403);
    $c->forward( $c->view('JSON') );
}

sub bad_request : Private {
    my ( $self, $c, $message, $code ) = @_;

    # XXX fix me
    #    $c->clear_stash;
    $c->stash( { message => $message || 'Bad request' } );
    $c->response->status( $code || 400 );
    $c->forward( $c->view('JSON') );
}

sub robots : Path("robots.txt") {
    my ( $self, $c ) = @_;
    $c->res->content_type("text/plain");
    $c->res->body("User-agent: *\nDisallow: /\n");
}

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    if (   $c->controller->does('MetaCPAN::Server::Role::JSONP')
        && $c->controller->enable_jsonp )
    {

        # See also: http://www.w3.org/TR/cors/
        if ( my $origin = $c->req->header('Origin') ) {
            $c->res->header( 'Access-Control-Allow-Origin' => $origin );
        }

        # call default view unless body has been set
        $c->forward( $c->view ) unless ( $c->res->body );
        $c->forward( $c->view('JSONP') );
        $c->res->content_type('text/javascript')
            if ( $c->req->params->{callback} );
    }

    if ( $c->cdn_max_age ) {

        # If we allow caching, we can serve stale content, if we error
        # on backend. Because we have caching on our UI (metacpan.org)
        # we don't really want to use stale_while_revalidate on
        # our API as otherwise the UI cacheing could be of old content
        $c->cdn_stale_if_error('1M');
    }
    else {
        # Default to telling fastly NOT to cache unless we have a
        # cdn cache time
        $c->cdn_never_cache(1);
    }

}

1;
