package MetaCPAN::Server::Controller::Pod;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub find : Path('') {
    my ( $self, $c, $author, $release, @path ) = @_;

    # $c->add_author_key($author) called from /source/get request below
    $c->cdn_max_age('1y');

    my $q = $c->req->query_params;
    for my $opt (qw(show_errors url_prefix)) {
        $c->stash->{$opt} = $q->{$opt}
            if exists $q->{$opt};
    }

    $c->stash->{link_mappings}
        = $self->find_dist_links( $c, $author, $release, !!$q->{permalinks} );

    $c->forward( '/source/get', [ $author, $release, @path ] );
    my $path = $c->stash->{path};
    $c->detach( '/bad_request', ['Requested resource is a binary file'] )
        if ( -B $path );
    $c->detach( '/bad_request',
        ['Requested resource is too large to be processed'] )
        if ( $path->stat->size > 2**21 );
    $c->forward( $c->view('Pod') );
}

sub get : Path('') : Args(1) {
    my ( $self, $c, $module ) = @_;
    $module = $c->model('ESModel')->doc('file')->find_pod($module)
        or $c->detach( '/not_found', [] );
    $c->forward( 'find', [ map { $module->$_ } qw(author release path) ] );
}

sub find_dist_links {
    my ( $self, $c, $author, $release, $permalinks ) = @_;
    my $modules
        = $c->model('ESQuery')->file->documented_modules( $author, $release );
    my $files = $modules->{files};

    my $links = {};

    for my $file (@$files) {
        my $name = $file->{documentation}
            or next;
        my ($module)
            = grep { $_->{name} eq $name } @{ $file->{module} };
        if ( $module && $module->{authorized} && $module->{indexed} ) {
            if ($permalinks) {
                $links->{$name} = join '/',
                    'release', $author, $release, $file->{path};
            }
            else {
                $links->{$name} = $name;
            }
        }
        next
            if exists $links->{$name};
        if ($permalinks) {
            $links->{$name} = join '/',
                'release', $author, $release, $file->{path};
        }
        else {
            $links->{$name} = join '/',
                'distribution', $file->{distribution}, $file->{path};
        }
    }
    return $links;
}

sub render : Path('/pod_render') Args(0) {
    my ( $self, $c ) = @_;
    my $pod         = $c->req->parameters->{pod};
    my $show_errors = !!$c->req->parameters->{show_errors};
    $c->res->content_type('text/x-pod');
    $c->res->body($pod);
    $c->stash( { show_errors => $show_errors } );
    $c->forward( $c->view('Pod') );
}

1;
