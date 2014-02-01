package MetaCPAN::Server::Controller::Search::History;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('') : Args {
    my ( $self, $c, @args ) = @_;
    my $data = $self->model($c)->history(@args)->raw;
    $c->stash( $data->all );
}

1;
