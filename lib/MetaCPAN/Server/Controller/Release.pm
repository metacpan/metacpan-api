package MetaCPAN::Server::Controller::Release;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

sub index : Chained('/') : PathPart('release') : CaptureArgs(0) {
}

sub find : Chained('index') : PathPart('') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;
    eval {
        $c->stash(
            $c->model('CPAN::Release')->inflate(0)->get(
                {   author => $author,
                    name   => $name,
                }
                )->{_source}
        );
    } or $c->detach('/not_found');
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $name ) = @_;
    eval {
        $c->stash(
            $c->model('CPAN::Release')->inflate(0)->find($name)->{_source} );
    } or $c->detach('/not_found');
}

1;
