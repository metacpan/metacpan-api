package MetaCPAN::Server::Model::User;

use strict;
use warnings;

use Moose;

extends 'MetaCPAN::Server::Model::CPAN';

has '+index' => ( default => 'user' );

1;
