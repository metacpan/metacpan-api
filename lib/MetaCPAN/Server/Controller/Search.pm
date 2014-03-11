package MetaCPAN::Server::Controller::Search;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub index : Chained('/') : PathPart('search') : CaptureArgs(0) {
}

1;
