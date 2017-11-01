package MetaCPAN::Server::Controller::ReverseDependencies;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

__PACKAGE__->config( namespace => 'reverse_dependencies' );

with 'MetaCPAN::Server::Role::JSONP';

sub dist : Path('dist') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    $c->stash_or_detach(
        $c->model('CPAN::Release')->reverse_dependencies(
            $dist, @{ $c->req->params }{qw< page page_size sort >}
        )
    );
}

sub module : Path('module') : Args(1) {
    my ( $self, $c, $module ) = @_;
    $c->stash_or_detach(
        $c->model('CPAN::Release')->requires(
            $module, @{ $c->req->params }{qw< page page_size sort >}
        )
    );
}

1;
