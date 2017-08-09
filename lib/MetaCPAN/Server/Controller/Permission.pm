package MetaCPAN::Server::Controller::Permission;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub by_author : Path('by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    $c->stash_or_detach( $self->model($c)->by_author($pauseid) );
}

sub by_module : Path('by_module') : Args(1) {
    my ( $self, $c, $module ) = @_;
    $c->stash_or_detach( $self->model($c)->by_modules($module) );
}

sub by_modules : Path('by_module') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach(
        $self->model($c)->by_modules( $c->read_param('module') ) );
}

__PACKAGE__->meta->make_immutable;
1;
