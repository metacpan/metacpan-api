package MetaCPAN::Server::Controller::Diff;

use strict;
use warnings;

use MetaCPAN::Server::Diff;
use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub index : Chained('/') : PathPart('diff') : CaptureArgs(0) {
}

# Diff two specific releases (/author/release/author/release).
sub diff_releases : Chained('index') : PathPart('release') : Args(4) {
    my ( $self, $c, @path ) = @_;
    my $path1 = $c->model('Source')->path( $path[0], $path[1] );
    my $path2 = $c->model('Source')->path( $path[2], $path[3] );

    my $diff = MetaCPAN::Server::Diff->new(
        source => $path1,
        target => $path2,
        git    => $c->config->{git},

        # use same dir prefix as source and target
        relative => $c->model('Source')->base_dir,
    );

    my $ct = eval { $c->req->preferred_content_type };
    if ( $ct && $ct eq 'text/plain' ) {
        $c->res->content_type('text/plain');
        $c->res->body( $diff->raw );
        $c->detach;
    }

    $c->stash(
        {
            source     => join( '/', $path[0], $path[1] ),
            target     => join( '/', $path[2], $path[3] ),
            statistics => $diff->structured,
        }
    );
}

# Only one distribution name specified: Diff latest with previous release.
sub release : Chained('index') : PathPart('release') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $release = eval {
        $c->model('CPAN::Release')->inflate(0)->find($name)->{_source};
    }
        or $c->detach('/not_found');
    my $with = eval {
        $c->model('CPAN::Release')->inflate(0)->predecessor($name)->{_source};
    }
        or $c->detach('/not_found');
    $c->forward( 'diff_releases',
        [ @$with{qw(author name)}, @$release{qw(author name)} ] );
}

# Diff two files (also works with directories).
sub file : Chained('index') : PathPart('file') : Args(2) {
    my ( $self, $c, $source, $target ) = @_;
    $source
        = eval { $c->model('CPAN::File')->inflate(0)->get($source)->{_source}; }
        or $c->detach('/not_found');
    $target
        = eval { $c->model('CPAN::File')->inflate(0)->get($target)->{_source}; }
        or $c->detach('/not_found');

    my $diff = MetaCPAN::Server::Diff->new(
        relative => $c->model('Source')->base_dir,
        source =>
            $c->model('Source')->path( @$source{qw(author release path)} ),
        target =>
            $c->model('Source')->path( @$target{qw(author release path)} ),
        git => $c->config->{git}
    );

    $c->stash(
        {
            source => join( '/', @$source{qw(author release path)} ),
            target => join( '/', @$target{qw(author release path)} ),
            statistics => $diff->structured,
            diff       => $diff->raw,
        }
    );
}

1;
