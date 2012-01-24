package MetaCPAN::Server::Controller::Distribution;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

sub index : Chained('/') : PathPart('distribution') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $name ) = @_;
    eval {
        $c->stash(
            $c->model('CPAN::Distribution')->inflate(0)->get($name)->{_source},
        );
    } or $c->detach('/not_found');
}

__PACKAGE__->meta->make_immutable;

1;
