package MetaCPAN::Server::Controller::Search::DownloadURL;

use strict;
use warnings;

use Moose;
use Try::Tiny qw( catch try );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('/download_url') : Args(1) {
    my ( $self, $c, $module ) = @_;
    my $type = $module eq 'perl' ? 'dist' : 'module';
    my $data = $self->_find_download_url( $c, $type, $module );
    return $c->detach( '/not_found', [] ) unless $data;
    $c->stash($data);
}

sub get_dist : Local : Path('/download_url/distribution') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    my $data = $self->_find_download_url( $c, 'dist', $dist );
    return $c->detach( '/not_found', [] ) unless $data;
    $c->stash($data);
}

sub _find_download_url {
    my ( $self, $c, $type, $name ) = @_;
    return try {
        $c->model('ESQuery')
            ->release->find_download_url( $type, $name, $c->req->params );
    }
    catch {
        die $_
            unless
            try { $_->isa('MetaCPAN::Query::Release::InvalidVersion') };
        $c->detach( '/bad_request', ['Invalid version parameter'] );
    };
}

1;
