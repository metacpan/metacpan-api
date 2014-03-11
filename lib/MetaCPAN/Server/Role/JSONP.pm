package MetaCPAN::Server::Role::JSONP;

use strict;
use warnings;

use Moose::Role;

has enable_jsonp => (
    is      => 'ro',
    default => 1,
);

1;
