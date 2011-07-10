package MetaCPAN::Server::Controller::Scroll;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }

sub index : Path('/_search/scroll') {
    my ( $self, $c ) = @_;
    my $req = $c->req;
    my $res = eval {
        $c->model('CPAN')->es->transport->request(
            {   method => $req->method,
                qs     => $req->parameters,
                cmd    => '/_search/scroll',
                data   => $req->data
            }
        );
    } or do { $self->internal_error( $c, $@ ); };
    $c->stash($res);
}

1;
