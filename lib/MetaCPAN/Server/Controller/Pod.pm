package MetaCPAN::Server::Controller::Pod;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }

sub index : Chained('/') : PathPart('pod') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args {
    my ( $self, $c, $author, $release, @path ) = @_;
    $c->forward('/source/get', [$author, $release, @path]);
    $c->forward($c->view('Pod'));
}

sub module : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $module ) = @_;
    $module = eval { $c->model('CPAN::File')->inflate(0)->find($module)->{_source} }
        or $c->detach('/not_found');
    $c->forward('get', [@$module{qw(author release path)}]);
}

1;
