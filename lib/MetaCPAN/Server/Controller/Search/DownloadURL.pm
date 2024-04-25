package MetaCPAN::Server::Controller::Search::DownloadURL;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('/download_url') : Args(1) {
    my ( $self, $c, $module ) = @_;
    my $type = 'module';
    my $data
        = $self->model($c)
        ->find_download_url( $type, $module, $c->req->params );
    return $c->detach( '/not_found', [] ) unless $data;
    $c->stash($data);
}

1;
