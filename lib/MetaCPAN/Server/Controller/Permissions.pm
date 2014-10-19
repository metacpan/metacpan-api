package MetaCPAN::Server::Controller::Permissions;

use strict;
use warnings;
use namespace::autoclean;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

__PACKAGE__->meta->make_immutable;
1;
