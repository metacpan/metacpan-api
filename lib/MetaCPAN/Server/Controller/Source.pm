package MetaCPAN::Server::Controller::Source;

use strict;
use warnings;

use Moose;
use Plack::App::Directory;
use Plack::MIME;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub index : Chained('/') : PathPart('source') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args {
    my ( $self, $c, $author, $release, @path ) = @_;

    $c->add_author_key($author);
    $c->cdn_max_age('1y');

    my $path = join( '/', @path );
    my $file = $c->model('Source')->path( $author, $release, $path )
        or $c->detach( '/not_found', [] );
    if ( $file->is_dir ) {
        $path = "/source/$author/$release/$path";
        $path =~ s/\/$//;
        my $env = $c->req->env;
        local $env->{PATH_INFO}   = '/';
        local $env->{SCRIPT_NAME} = $path;
        my $res = Plack::App::Directory->new( { root => $file->stringify } )
            ->to_app->($env);

        $c->res->content_type('text/html');
        $c->res->body( $res->[2]->[0] );
    }
    else {
        $c->stash->{path} = $file;

        # Tell fastly to cache for a day (for st.aticpan.org,
        # api.metacpan.org does not go through fastly)
        my $max_age_seconds = 60 * 60 * 24;
        $c->res->header(
            'Surrogate-Control' => "max-age=${max_age_seconds}" );

        # Add X-Content-Type header, for fastly to rewrite on st.aticpan.org
        $c->res->header( 'X-Content-Type' => Plack::MIME->mime_type($file)
                || 'text/plain' );
        $c->res->content_type('text/plain');
        $c->res->body( $file->openr );
    }
}

sub module : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $module ) = @_;
    $module = $c->model('CPAN::File')->find($module)
        or $c->detach( '/not_found', [] );
    $c->forward( 'get', [ map { $module->$_ } qw(author release path) ] );
}

1;
