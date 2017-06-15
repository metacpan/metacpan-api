package MetaCPAN::Server::Controller::ReverseDependencies;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

__PACKAGE__->config( namespace => 'reverse_dependencies' );

with 'MetaCPAN::Server::Role::JSONP';

sub dist : Path('dist') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    my $data = $c->model('CPAN::Release')->reverse_dependencies($dist);
    $c->detach('/not_found') unless $data;
    $c->stash($data);
}

sub module : Path('module') : Args(1) {
    my ( $self, $c, $module ) = @_;
    my @params = @{ $c->req->params }{qw< page page_size sort >};
    my $data = $c->model('CPAN::Release')->raw->requires( $module, @params );
    $c->detach('/not_found') unless $data;
    $c->stash($data);
}

1;
