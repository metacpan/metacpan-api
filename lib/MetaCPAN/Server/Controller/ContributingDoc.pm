package MetaCPAN::Server::Controller::ContributingDoc;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub index : Chained('/') : PathPart('contributing_doc') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;

    $c->add_author_key($author);
    $c->cdn_max_age('1y');

    my $file = $c->model('CPAN::File')
        ->find_contributing_files( $author, $release );
    $file or $c->detach( '/not_found', [] );

    $c->stash($file);
}

__PACKAGE__->meta->make_immutable;

1;
