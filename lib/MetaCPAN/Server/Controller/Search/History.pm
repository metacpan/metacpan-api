package MetaCPAN::Server::Controller::Search::History;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('') : Args {
    my ( $self, $c, $type, $name, @path ) = @_;
    my $fields = $c->res->fields;
    my $data   = $c->model('ESQuery')
        ->file->history( $type, $name, \@path, { fields => $fields } );
    $c->stash($data);
}

1;
