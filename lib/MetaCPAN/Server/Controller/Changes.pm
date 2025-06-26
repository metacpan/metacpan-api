package MetaCPAN::Server::Controller::Changes;

use strict;
use warnings;
use namespace::autoclean;

use Encode ();
use Moose;
use Try::Tiny qw( try );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub index : Chained('/') : PathPart('changes') : CaptureArgs(0) {
}

# https://fastapi.metacpan.org/v1/changes/LLAP/CatalystX-Fastly-Role-Response-0.04
sub get : Chained('index') : PathPart('') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;

    $c->add_author_key($author);
    $c->cdn_max_age('1y');

    my $file
        = $c->model('ESQuery')->file->find_changes_files( $author, $release );
    $file or $c->detach( '/not_found', [] );

    my $source = $c->model('Source')->path( @$file{qw(author release path)} )
        or $c->detach( '/not_found', [] );

    $file->{content} = try {
        local $/;
        my $content = $source->openr->getline;

        # Assume files are in UTF-8 (if not, do nothing)
        # (see comments in metacpan-web/lib/MetaCPAN/Web/Model/API.pm).
        try {
            $content = Encode::decode( 'UTF-8', $content,
                Encode::FB_CROAK | Encode::LEAVE_SRC );
        };

        $content;
    };

    $file = $self->apply_request_filter( $c, $file );

    $c->stash($file);
}

sub find : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $release = eval { $c->model('ESQuery')->release->find($name); }
        or $c->detach( '/not_found', [] );

    $c->forward( 'get', [ @$release{qw( author name )} ] );
}

sub all : Chained('index') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->detach('not_found');
}

sub by_releases : Path('by_releases') : Args(0) {
    my ( $self, $c ) = @_;

    my @releases = map {
        my @o = split( '/', $_, 2 );
        @o == 2 ? { author => $o[0], name => $o[1] } : ();
    } @{ $c->read_param("release") };

    unless (@releases) {
        $c->stash( { changes => [] } );
        return;
    }

    my $ret
        = $c->model('ESQuery')->release->by_author_and_names( \@releases );

    my @changes;
    for my $release ( @{ $ret->{releases} } ) {
        my ( $author, $name, $path )
            = @{$release}{qw(author name changes_file)};
        next
            unless $path;
        my $source = $c->model('Source')->path( $author, $name, $path )
            or next;

        my $content = try {
            Encode::decode(
                'UTF-8',
                ( scalar $source->slurp ),
                Encode::FB_CROAK | Encode::LEAVE_SRC
            );
        } or next;

        push @changes,
            {
            author       => $author,
            release      => $name,
            changes_text => $content,
            changes_file => $path,
            };
    }

    $c->stash( { changes => \@changes } );
}

1;
