package MetaCPAN::Server::Controller::Permission;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub by_author : Path('by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    my $data = $self->model($c)->raw->by_author($pauseid);

    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

sub by_module : Path('by_module') : Args(1) {
    my ( $self, $c, $module ) = @_;
    my $data = $self->model($c)->raw->by_modules($module);

    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

sub by_modules : Path('by_module') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->by_modules( $c->read_param('module') );

    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

__PACKAGE__->meta->make_immutable;
1;
