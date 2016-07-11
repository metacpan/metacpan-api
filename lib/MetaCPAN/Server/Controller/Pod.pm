package MetaCPAN::Server::Controller::Pod;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub find : Path('') {
    my ( $self, $c, $author, $release, @path ) = @_;
    $c->stash->{link_mappings}
        = $self->find_dist_links( $c, $author, $release,
        !!$c->req->query_params->{permalinks} );

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
    $module = $c->model('CPAN::File')->find_pod($module)
        or $c->detach( '/not_found', [] );
    $c->forward( 'find', [ map { $module->$_ } qw(author release path) ] );
}

sub find_dist_links {
    my ( $self, $c, $author, $release, $permalinks ) = @_;
    my $module_query
        = $c->model('CPAN::File')
        ->documented_modules( { name => $release, author => $author } )
        ->source( [qw(name module path documentation distribution)] );
    my @modules = $module_query->all;

    my $links = {};

    for my $file (@modules) {
        next
            unless $file->has_documentation;
        my $name = $file->documentation;
        my ($module)
            = grep { $_->name eq $name } @{ $file->module };
        if ( $module && $module->authorized && $module->indexed ) {
            if ($permalinks) {
                $links->{$name} = join '/',
                    'release', $author, $release, $file->path;
            }
            else {
                $links->{$name} = $name;
            }
        }
        next
            if exists $links->{$name};
        if ($permalinks) {
            $links->{$name} = join '/',
                'release', $author, $release, $file->path;
        }
        else {
            $links->{$name} = join '/',
                'distribution', $file->distribution, $file->path;
        }
    }
    return $links;
}

1;
