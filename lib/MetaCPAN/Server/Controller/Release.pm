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
    my $file = $self->model($c)->find($name);
    $c->detach( '/not_found', [] ) unless $file;
    $c->stash($file);
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
    $c->stash_or_detach(
        $self->model($c)->get_contributors( $author, $release ) );
}

sub files : Path('files') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $files = $c->req->params->{files};
    $c->detach( '/bad_request', ['No files requested'] ) unless $files;
    $c->stash_or_detach(
        $self->model($c)->get_files( $name, [ split /,/, $files ] ) );
}

sub modules : Path('modules') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;
    $c->stash_or_detach( $self->model($c)->modules( $author, $name ) );
}

sub recent : Path('recent') : Args(0) {
    my ( $self, $c ) = @_;
    my @params = @{ $c->req->params }{qw( page page_size type )};
    $c->stash_or_detach( $self->model($c)->recent(@params) );
}

sub by_author_and_name : Path('by_author_and_name') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;
    $c->stash_or_detach(
        $self->model($c)->by_author_and_name( $author, $name ) );
}

sub by_author : Path('by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    $c->stash_or_detach(
        $self->model($c)->by_author( $pauseid, $c->req->param('size') ) );
}

sub latest_by_distribution : Path('latest_by_distribution') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    $c->add_dist_key($dist);
    $c->stash_or_detach( $self->model($c)->latest_by_distribution($dist) );
}

sub latest_by_author : Path('latest_by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    $c->stash_or_detach( $self->model($c)->latest_by_author($pauseid) );
}

sub all_by_author : Path('all_by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    my @params = @{ $c->req->params }{qw( page page_size )};
    $c->stash_or_detach(
        $self->model($c)->all_by_author( $pauseid, @params ) );
}

sub versions : Path('versions') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    $c->add_dist_key($dist);
    $c->stash_or_detach( $self->model($c)->versions($dist) );
}

sub top_uploaders : Path('top_uploaders') : Args() {
    my ( $self, $c ) = @_;
    my $range = $c->req->param('range') || 'weekly';
    $c->stash_or_detach( $self->model($c)->top_uploaders($range) );
}

sub interesting_files : Path('interesting_files') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;
    $c->stash_or_detach(
        $c->model('CPAN::File')->interesting_files( $author, $release ) );
}

__PACKAGE__->meta->make_immutable;
1;
