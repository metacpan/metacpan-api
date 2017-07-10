package MetaCPAN::Server::Controller::Rating;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub by_distributions : Path('by_distributions') : Args(0) {
    my ( $self, $c ) = @_;
    my $distributions
        = $c->req->body_data
        ? $c->req->body_data->{distribution}
        : [ $c->req->param('distribution') ];
    $c->detach( '/bad_request', ['No distributions requested'] )
        unless $distributions and @{$distributions};

    my $data = $self->model($c)->raw->by_distributions($distributions);

    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

1;
