package MetaCPAN::API::Model::Download;

use Mojo::Base -base;

use Carp ();

has es => sub { Carp::croak 'es is required' };

1;

