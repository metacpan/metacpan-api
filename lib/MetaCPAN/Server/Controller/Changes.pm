package MetaCPAN::Server::Controller::Changes;

use strict;
use warnings;
use namespace::autoclean;

use Encode ();
use Moose;
use Try::Tiny;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

# TODO: __PACKAGE__->config(relationships => ?)

has '+type' => ( default => 'file' );

sub index : Chained('/') : PathPart('changes') : CaptureArgs(0) {
}

# https://fastapi.metacpan.org/v1/changes/LLAP/CatalystX-Fastly-Role-Response-0.04
sub get : Chained('index') : PathPart('') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;

    $c->add_author_key($author);
    $c->cdn_max_age('1y');

    my $file
        = $c->model('CPAN::File')->find_changes_files( $author, $release );
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
    my $release = eval { $c->model('CPAN::Release')->find($name); }
        or $c->detach( '/not_found', [] );

    $c->forward( 'get', [ @$release{qw( author name )} ] );
}

sub all : Chained('index') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->detach('not_found');
}

1;
