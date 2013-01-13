package MetaCPAN::Server::Controller::Distribution;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';


__PACKAGE__->meta->make_immutable;
