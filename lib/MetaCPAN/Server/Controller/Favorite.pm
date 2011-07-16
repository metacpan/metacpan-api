package MetaCPAN::Server::Controller::Favorite;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }

sub index : Chained('/') : PathPart('favorite') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $id ) = @_;
    eval {
        $c->stash(
            $c->model('CPAN::Favorite')->inflate(0)->get($id)->{_source} );
    } or $c->detach('/not_found');
}

1;
