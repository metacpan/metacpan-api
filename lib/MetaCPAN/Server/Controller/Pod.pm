package MetaCPAN::Server::Controller::Pod;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

sub index : Chained('/') : PathPart('pod') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args {
    my ( $self, $c, $author, $release, @path ) = @_;
    $c->forward( '/source/get', [ $author, $release, @path ] );
    my $path = $c->stash->{path};
    $c->detach( '/bad_request', ['Requested resource is a binary file'] )
        if ( -B $path );
    $c->detach( '/bad_request',
        ['Requested resource is too large to be processed'] )
        if ( $path->stat->size > 2**20 );
    $c->forward( $c->view('Pod') );
}

sub module : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $module ) = @_;
    $module = $c->model('CPAN::File')->find_pod($module) or $c->detach('/not_found');
    $c->forward( 'get', [ map { $module->$_ } qw(author release path) ] );
}

1;
