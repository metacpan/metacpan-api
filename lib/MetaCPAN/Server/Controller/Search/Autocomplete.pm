package MetaCPAN::Server::Controller::Search::Autocomplete;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Local : Path('') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $c->model('CPAN::File')->autocomplete($c->req->param("q"))->raw
        ->fields( [qw(documentation release author distribution)] );
    $c->stash($data->all);
}

1;
