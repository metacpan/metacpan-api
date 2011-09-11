package MetaCPAN::Server::View::JSONP;
use Moose;
extends 'Catalyst::View';

sub process {
    my ($self, $c) = @_;
    return 1 unless(my $cb = $c->req->params->{callback});
    $c->res->body(
        "$cb(" . $c->res->body . ");"   
    );
    return 1;
}

1;