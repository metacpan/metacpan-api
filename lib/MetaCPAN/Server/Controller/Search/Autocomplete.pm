package MetaCPAN::Server::Controller::Search::Autocomplete;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    my $model = $self->model($c);
    $model = $model->fields( [qw(documentation release author distribution)] )
        unless $model->fields;
    my $data = $model->autocomplete( $c->req->param("q") )->raw;
    $c->stash( $data->all );
}

1;
