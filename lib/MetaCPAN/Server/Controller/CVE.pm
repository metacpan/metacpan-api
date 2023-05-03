package MetaCPAN::Server::Controller::CVE;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( digest );

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

1;
