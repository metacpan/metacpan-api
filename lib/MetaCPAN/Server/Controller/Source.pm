package MetaCPAN::Server::Controller::Source;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }

sub index : Chained('/') : PathPart('source') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args {
    my ( $self, $c, $author, $release, @path ) = @_;
    my $file
        = $c->model('Source')->path( $author, $release, join( '/', @path ) )
        or $c->detach('/not_found');
    $c->res->content_type('text/plain');
    $c->res->body($file->openr);
}

sub module : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $module ) = @_;
    $module = $c->stash( $c->model('CPAN::File')->inflate(0)->get($module) )
        or $c->detach('/not_found');
    $c->forward( 'get', [ @$module{qw(author release path)} ] );
}

1;
