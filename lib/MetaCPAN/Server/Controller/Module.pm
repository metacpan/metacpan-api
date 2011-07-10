package MetaCPAN::Server::Controller::Module;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller::File' }

sub index : Chained('/') : PathPart('module') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $module ) = @_;
    eval {
        $c->stash(
            $c->model('CPAN::File')->inflate(0)->find($module)->{_source} );
    } or $c->detach('/not_found');
}

1;
