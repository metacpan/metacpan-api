package MetaCPAN::Server::Controller::Rating;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }

sub index : Chained('/') : PathPart('rating') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $id ) = @_;
    eval {
        $c->stash($c->model('CPAN::Rating')->inflate(0)->get($id)->{_source});
    } or $c->detach('/not_found');

}

1;
