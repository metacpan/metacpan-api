package MetaCPAN::Server::Controller::Contributor;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( digest );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub get : Path('') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;
    my $data
        = $self->model($c)->raw->find_release_contributors( $author, $name );
    return unless $data;
    $c->stash($data);
}

sub by_pauseid : Path('by_pauseid') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    my $data = $self->model($c)->raw->find_author_contributions($pauseid);
    return unless $data;
    $c->stash($data);
}

1;
