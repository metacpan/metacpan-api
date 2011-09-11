package MetaCPAN::Server::View::JSONP;
use Moose;
use Encode qw(decode_utf8);
extends 'Catalyst::View';

sub process {
    my ($self, $c) = @_;
    return 1 unless(my $cb = $c->req->params->{callback});
    $c->res->body(
        "$cb(" . decode_utf8($c->res->body) . ");"
    );
    return 1;
}

1;