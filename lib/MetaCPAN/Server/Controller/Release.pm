package MetaCPAN::Server::Controller::Release;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

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
    $c->stash( $file->{_source}
            || single_valued_arrayref_to_scalar( $file->{fields} ) )
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
    $c->stash( $file->{_source}
            || single_valued_arrayref_to_scalar( $file->{fields} ) )
        || $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

sub contributors : Path('contributors') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;
    my $data = $self->model($c)->raw->get_contributors( $author, $release );
    $c->stash($data);
}

sub files : Path('files') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $files = $c->req->params->{files};
    return unless $files;
    my @files = split /,/, $files;
    my $data = $self->model($c)->raw->get_files( $name, \@files );
    $c->stash($data);
}

# TODO: remove after deployed in Controller::ReverseDependencies
sub requires : Path('requires') : Args(1) {
    my ( $self, $c, $module ) = @_;
    my @params = @{ $c->req->params }{qw< page page_size sort >};
    my $data = $self->model($c)->raw->requires( $module, @params );
    return unless $data;
    $c->stash($data);
}

sub latest_by_author : Path('latest_by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    my $data = $self->model($c)->raw->latest_by_author($pauseid);
    return unless $data;
    $c->stash($data);
}

sub all_by_author : Path('all_by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    my @params = @{ $c->req->params }{qw< page page_size >};
    my $data = $self->model($c)->raw->all_by_author( $pauseid, @params );
    return unless $data;
    $c->stash($data);
}

sub versions : Path('versions') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    my $data = $self->model($c)->raw->versions($dist);
    return unless $data;
    $c->stash($data);
}

sub top_uploaders : Path('top_uploaders') : Args() {
    my ( $self, $c ) = @_;
    my $range = $c->req->param('range') || 'weekly';
    my $data = $self->model($c)->raw->top_uploaders($range);
    return unless $data;
    $c->stash($data);
}

__PACKAGE__->meta->make_immutable;
1;
