package MetaCPAN::Server::Controller::Permission;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub by_author : Path('by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    my $data = $self->model($c)->raw->by_author($pauseid);
    return unless $data;
    $c->stash($data);
}

sub by_module : Path('by_module') : Args(1) {
    my ( $self, $c, $module ) = @_;
    my $data = $self->model($c)->raw->by_modules($module);
    return unless $data;
    $c->stash($data);
}

sub by_modules : Path('by_module') : Args(0) {
    my ( $self, $c ) = @_;
    my @modules = $c->req->param('module');
    my $data    = $self->model($c)->raw->by_modules( \@modules );
    return unless $data;
    $c->stash($data);
}

__PACKAGE__->meta->make_immutable;
1;
