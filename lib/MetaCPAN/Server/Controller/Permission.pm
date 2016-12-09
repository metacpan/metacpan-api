package MetaCPAN::Server::Controller::Permission;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

__PACKAGE__->meta->make_immutable;
1;
