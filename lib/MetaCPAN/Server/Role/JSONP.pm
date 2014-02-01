package MetaCPAN::Server::Role::JSONP;
use Moose::Role;
has enable_jsonp => ( is => 'ro', default => 1 );
1;
