package MetaCPAN::Server::View::JSONP;
use Moose;
use Encode qw(decode_utf8);
use JSON::XS qw();
extends 'Catalyst::View';

sub process {
    my ($self, $c) = @_;
    return 1 unless(my $cb = $c->req->params->{callback});
    my $body = decode_utf8($c->res->body);
    my $content_type = $c->res->content_type;
    if($content_type ne 'application/json') {
        if(my($key) = $content_type =~ m{^text/(.*)$}) {
            $body = JSON::XS->new->utf8->encode({ $key => $body });
        }
    }
    $c->res->body( "$cb($body);" );
    return 1;
}

1;