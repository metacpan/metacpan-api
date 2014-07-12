package MetaCPAN::Server::View::JSONP;

use strict;
use warnings;

use Encode qw(decode_utf8);
use JSON ();
use Moose;

extends 'Catalyst::View';

sub process {
    my ( $self, $c ) = @_;
    return 1 unless ( my $cb = $c->req->params->{callback} );
    my $body = $c->res->body;
    if ( ref($body) ) {
        local ($/);
        $body = <$body>;
    }
    $body = decode_utf8($body);
    my $content_type = $c->res->content_type;
    return 1 if ( $content_type eq 'text/javascript' );
    if ( $content_type ne 'application/json' ) {
        $body = JSON->new->allow_nonref->ascii->encode($body);
    }
    $c->res->body("/**/$cb($body);");
    return 1;
}

1;
