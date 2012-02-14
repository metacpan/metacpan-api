package MetaCPAN::Server::Controller::Module;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller::File' }

has '+type' => ( default => 'file' );

sub index : Chained('/') : PathPart('module') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $module ) = @_;
    eval {
        $module = $c->model('CPAN::File')->find($module) or die;
        $c->stash(
            $module->meta->get_data($module) );
    } or $c->detach('/not_found');
}

1;
