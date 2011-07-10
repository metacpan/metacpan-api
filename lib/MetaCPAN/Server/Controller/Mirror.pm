package MetaCPAN::Server::Controller::Mirror;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }

sub index : Chained('/') : PathPart('mirror') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $id ) = @_;
    eval {
        $c->stash(
            $c->model('CPAN::Mirror')->inflate(0)->get($id)->{_source} );
    } or $c->detach('/not_found');
}

1;
