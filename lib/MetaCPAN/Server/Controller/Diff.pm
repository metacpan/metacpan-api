package MetaCPAN::Server::Controller::Diff;

use strict;
use warnings;

use MetaCPAN::Server::Diff ();
use Moose;
use namespace::autoclean;
use Try::Tiny qw( catch try );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub index : Chained('/') : PathPart('diff') : CaptureArgs(0) {
}

# Diff two specific releases (/author/release/author/release).
sub diff_releases : Chained('index') : PathPart('release') : Args(4) {
    my ( $self, $c, @path ) = @_;

    $c->add_author_key( $path[0] );
    $c->add_author_key( $path[2] ) unless $path[0] eq $path[2];
    $c->cdn_max_age('1y');

    # Use author/release as top dirs for diff.
    $self->_do_diff( $c, [ $path[0], $path[1] ], [ $path[2], $path[3] ] );
}

# Only one distribution name specified: Diff latest with previous release.
sub release : Chained('index') : PathPart('release') : Args(1) {
    my ( $self, $c, $name ) = @_;

    my ( $latest, $previous );
    try {
        $latest   = $c->model('CPAN::Release')->find($name);
        $previous = $c->model('CPAN::Release')->predecessor($name);
    }
    catch {
        $c->detach('/not_found');
    };

    $self->_do_diff( $c,
        ( map { [ @$_{qw(author name)} ] } $previous, $latest ) );
}

# Diff two files (also works with directories).
# eg. /diff/file/8yTixXQGpkbPsMBXKvDoJV4Qkg8/dPgxn7qq0wm1l_UO1aIMyQWFJPw
sub file : Chained('index') : PathPart('file') : Args(2) {
    my ( $self, $c, $source, $target ) = @_;

    $c->cdn_max_age('1y');

    my ( $source_args, $target_args )
        = map { [ @$_{qw(author release path)} ] }
        map {
        my $file = $_;
        try { $c->model('CPAN::File')->raw->get($file)->{_source}; }
            or $c->detach('/not_found');
        } ( $source, $target );

    $self->_do_diff( $c, $source_args, $target_args, 1 );
}

sub _do_diff {
    my ( $self, $c, $source, $target, $include_raw ) = @_;

    my $diff = MetaCPAN::Server::Diff->new(
        source => scalar $c->model('Source')->path(@$source),
        target => scalar $c->model('Source')->path(@$target),

        # use same dir prefix as source and target
        relative => scalar $c->model('Source')->base_dir,
        git      => $c->config->{git}
    );

    # As of Catalyst::TraitFor::Request::REST 1.17 this method will error
    # if request contains no content-type hints (undef not a Str).
    my $ct = try { $c->req->preferred_content_type };

    if ( $ct && $ct eq 'text/plain' ) {
        $c->res->content_type('text/plain');
        $c->res->body( $diff->raw );
        $c->detach;
    }

    $c->stash( {
        source     => join( q[/], @$source ),
        target     => join( q[/], @$target ),
        statistics => $diff->structured,
        $include_raw ? ( diff => $diff->raw ) : (),
    } );
}

1;
