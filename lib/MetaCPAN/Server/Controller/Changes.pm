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

sub get : Chained('index') : PathPart('') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;

    # find the most likely file
    # TODO: should we do this when the release is indexed
    # and store the result as { 'changes_file' => $name }

    my @candidates = qw(
        CHANGES Changes ChangeLog Changelog CHANGELOG NEWS
    );

    my $file = eval {

        # use $c->model b/c we can't let any filters apply here
        my $files = $c->model('CPAN::File')->raw->filter(
            {
                and => [
                    { term => { release => $release } },
                    { term => { author  => $author } },
                    {
                        or => [

                            # if it's a perl release, get perldelta
                            {
                                and => [
                                    { term => { distribution => 'perl' } },
                                    {
                                        term => {
                                            'name' => 'perldelta.pod'
                                        }
                                    },
                                ]
                            },

                      # otherwise look for one of these candidates in the root
                            {
                                and => [
                                    { term => { level     => 0 } },
                                    { term => { directory => 0 } },
                                    {
                                        or => [
                                            map {
                                                { term => { 'name' => $_ } }
                                            } @candidates
                                        ]
                                    }
                                ]
                            }
                        ],
                    }
                ]
            }
            )->size(1)

           # HACK: Sort by level/desc to put pod/perldeta.pod first (if found)
           # otherwise sort root files by name and select the first.
            ->sort( [ { level => 'desc' }, { name => 'asc' } ] )
            ->first->{_source};
    } or $c->detach( '/not_found', [] );

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
    my $release
        = eval { $c->model('CPAN::Release')->raw->find($name)->{_source}; }
        or $c->detach( '/not_found', [] );

    $c->forward( 'get', [ @$release{qw( author name )} ] );
}

sub all : Chained('index') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->detach('not_found');
}

1;
