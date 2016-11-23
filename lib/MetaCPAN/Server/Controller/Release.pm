package MetaCPAN::Server::Controller::Release;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

__PACKAGE__->config(
    relationships => {
        author => {
            type    => 'Author',
            foreign => 'pauseid',
        }
    }
);

sub find : Path('') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $file = $self->model($c)->raw->find($name);
    if ( !defined $file ) {
        $c->detach( '/not_found', [] );
    }
    $c->stash( $file->{_source} || $file->{fields} )
        || $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

sub get : Path('') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;

    $c->add_author_key($author);
    $c->cdn_max_age('1y');

    my $file = $self->model($c)->raw->get(
        {
            author => $author,
            name   => $name,
        }
    );
    if ( !defined $file ) {
        $c->detach( '/not_found', [] );
    }
    $c->stash( $file->{_source} || $file->{fields} )
        || $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

# endpoint: /release/latest_by_author/AUTHOR
# params:   [&fields=<field>][&sort=<sort_key>][&size=N]
sub latest_by_author : Path('latest_by_author') : Args(1) {
    my ( $self, $c, $author ) = @_;
    my $data = $self->model($c)->raw->latest_by_author($author);
    $c->stash($data);
}

# endpoint: /release/by_name_and_author
# params:   name=<name>&author=<author>[&fields=<field>][&sort=<sort_key>][&size=N]
sub by_name_and_author : Path('by_name_and_author') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->by_name_and_author( $c->req );
    $c->stash($data);
}

# endpoint: /release/versions
# params:   distribution=<distribution>[&fields=<field>][&sort=<sort_key>][&size=N]
sub versions : Path('versions') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->versions( $c->req );
    $c->stash($data);
}

__PACKAGE__->meta->make_immutable;
1;
