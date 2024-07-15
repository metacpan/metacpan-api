package MetaCPAN::Server::Controller::CVE;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub get : Path('') : Args(1) {
    my ( $self, $c, $cpansa_id ) = @_;
    $c->stash_or_detach( $self->model($c)->find_cves_by_cpansa($cpansa_id) );
}

sub release : Path('release') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;
    $c->stash_or_detach(
        $self->model($c)->find_cves_by_release( $author, $release ) );
}

sub dist : Path('dist') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    my $version = $c->req->query_params->{version};
    $c->stash_or_detach(
        $self->model($c)->find_cves_by_dist( $dist, $version ) );
}

1;
