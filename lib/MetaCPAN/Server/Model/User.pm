package MetaCPAN::Server::Model::User;

use Moose;
extends 'MetaCPAN::Server::Model::CPAN';
__PACKAGE__->config( index => 'user' );

1;
