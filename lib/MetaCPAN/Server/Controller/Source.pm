package MetaCPAN::Server::Controller::Source;

use strict;
use warnings;

use Moose;
use Plack::App::Directory ();
use Plack::MIME           ();

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub index : Chained('/') : PathPart('source') : CaptureArgs(0) {
}

# e.g. /source/DOY/Moose-0.01/MANIFEST or /source/DOY/Moose-0.01/
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

        # Add X-Content-Type header, for fastly to rewrite on st.aticpan.org
        my $type = Plack::MIME->mime_type($file) || 'text/plain';
        $c->res->header( 'X-Content-Type' => $type );
        if ( $type =~ m{^image/} ) {
            $c->res->content_type($type);
        }
        elsif ( $type
            =~ m{^(?:text/.*|application/javascript|application/json)$} )
        {
            $c->res->content_type('text/plain');
        }
        else {
            $c->res->content_type('application/octet-stream');
        }
        $c->res->body( $file->openr );
    }
}

# e.g. /source/Moose
sub module : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $module ) = @_;

    $c->cdn_never_cache(1);

    $module = $c->model('CPAN::File')->find($module)
        or $c->detach( '/not_found', [] );
    $c->forward( 'get', [ map { $module->$_ } qw(author release path) ] );
}

1;
