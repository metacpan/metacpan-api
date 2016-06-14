package MetaCPAN::Tests::Role::HasApp;

use strict;
use warnings;

use MetaCPAN::TestApp;
use Moose::Role;

has app => (
    is      => 'ro',
    isa     => 'MetaCPAN::TestApp',
    lazy    => 1,
    default => sub { MetaCPAN::TestApp->new },
);

1;
