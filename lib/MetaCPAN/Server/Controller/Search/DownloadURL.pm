package MetaCPAN::Server::Controller::Search::DownloadURL;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('/download_url') : Args(1) {
    my ( $self, $c, $module ) = @_;
    my $args = $c->req->params;

    my $model = $self->model($c);
    my $res = $model->find_download_url( $module, $args )->raw->all;
    my $hit = $res->{hits}{hits}[0]
        or return $c->detach( '/not_found', [] );

    $c->stash(
        {   %{ $hit->{_source} },
            %{ $hit->{inner_hits}{module}{hits}{hits}[0]{_source} }
        }
    );
}

1;
