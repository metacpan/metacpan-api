package MetaCPAN::Server::Model::User;

use Moose;
extends 'MetaCPAN::Server::Model::CPAN';
has '+index' => ( default => 'user' );

1;
