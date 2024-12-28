package MetaCPAN::Server::Controller::Release;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub find : Path('') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $file = $c->model('ESQuery')->release->find($name);
    $c->detach( '/not_found', [] ) unless $file;
    $c->stash($file);
}

sub get : Path('') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;
    $c->add_author_key($author);
    $c->cdn_max_age('1y');
    $c->stash_or_detach(
        $c->model('ESQuery')->release->by_author_and_name( $author, $name ) );
}

sub contributors : Path('contributors') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;
    $c->stash_or_detach(
        $c->model('ESQuery')->release->get_contributors( $author, $release )
    );
}

sub files : Path('files') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $files = $c->req->params->{files};
    $c->detach( '/bad_request', ['No files requested'] ) unless $files;
    $c->stash_or_detach( $c->model('ESQuery')
            ->release->get_files( $name, [ split /,/, $files ] ) );
}

sub modules : Path('modules') : Args(2) {
    my ( $self, $c, $author, $name ) = @_;
    $c->stash_or_detach(
        $c->model('ESQuery')->release->modules( $author, $name ) );
}

sub recent : Path('recent') : Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->params;
    my $type   = $params->{type};
    my $page   = $params->{page};
    my $size   = $params->{page_size};
    $c->stash_or_detach(
        $c->model('ESQuery')->release->recent( $type, $page, $size ) );
}

sub by_author : Path('by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    my $params = $c->req->params;
    my $page   = $params->{page};
    my $size   = $params->{page_size} // $params->{size};
    $c->stash_or_detach(
        $c->model('ESQuery')->release->by_author( $pauseid, $page, $size ) );
}

sub latest_by_distribution : Path('latest_by_distribution') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    $c->add_dist_key($dist);
    $c->cdn_max_age('1y');
    $c->stash_or_detach(
        $c->model('ESQuery')->release->latest_by_distribution($dist) );
}

sub latest_by_author : Path('latest_by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    $c->stash_or_detach(
        $c->model('ESQuery')->release->latest_by_author($pauseid) );
}

sub all_by_author : Path('all_by_author') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    my $params = $c->req->params;
    my $page   = $params->{page};
    my $size   = $params->{page_size};
    $c->stash_or_detach(
        $c->model('ESQuery')->release->all_by_author( $pauseid, $page, $size )
    );
}

sub versions : Path('versions') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    my %params = %{ $c->req->params }{qw( plain versions )};
    $c->add_dist_key($dist);
    $c->cdn_max_age('1y');
    my $data = $c->model('ESQuery')
        ->release->versions( $dist, [ split /,/, $params{versions} || '' ] );

    if ( $params{plain} ) {
        my $data = join "\n",
            map { join "\t", @{$_}{qw/ version download_url /} }
            @{ $data->{releases} };
        $c->res->body($data);
        $c->res->content_type('text/plain');
    }
    else {
        $c->stash_or_detach($data);
    }
}

sub top_uploaders : Path('top_uploaders') : Args() {
    my ( $self, $c ) = @_;
    my $range = $c->req->param('range') || 'weekly';
    $c->stash_or_detach(
        $c->model('ESQuery')->release->top_uploaders($range) );
}

sub interesting_files : Path('interesting_files') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;
    my $categories = $c->read_param( 'category', 1 );
    $c->stash_or_detach( $c->model('ESQuery')
            ->file->interesting_files( $author, $release, $categories ) );
}

sub files_by_category : Path('files_by_category') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;
    my $categories = $c->read_param( 'category', 1 );
    $c->stash_or_detach( $c->model('ESQuery')
            ->file->files_by_category( $author, $release, $categories ) );
}

__PACKAGE__->meta->make_immutable;
1;
