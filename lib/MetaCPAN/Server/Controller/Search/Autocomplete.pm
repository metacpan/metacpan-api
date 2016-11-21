package MetaCPAN::Server::Controller::Search::Autocomplete;

use strict;
use warnings;

use Moose;
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    my $model = $self->model($c);
    $model = $model->fields( [qw(documentation release author distribution)] )
        unless $model->fields;
    my $data
        = $model->autocomplete( $c->req->param("q") )->source(0)->raw->all;

    single_valued_arrayref_to_scalar( $_->{fields} )
        for @{ $data->{hits}{hits} };

    $c->stash($data);
}

1;
