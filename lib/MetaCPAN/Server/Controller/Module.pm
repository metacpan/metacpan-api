package MetaCPAN::Server::Controller::Module;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller::File' }

has '+type' => ( default => 'file' );

sub index : Chained('/') : PathPart('module') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $module ) = @_;
    $module = $c->model('CPAN::File')->find($module)
        or $c->detach( '/not_found', [$@] );
    $c->stash( $module->meta->get_data($module) );
}

1;
