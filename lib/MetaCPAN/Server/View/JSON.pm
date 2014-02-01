package MetaCPAN::Server::View::JSON;
use Moose;
extends 'Catalyst::View::JSON';

use JSON::XS;

no warnings 'redefine';

sub encode_json($) {
    my ( $self, $c, $data ) = @_;
    my $encoder
        = $c->req->looks_like_browser
        ? JSON::XS->new->utf8->pretty
        : JSON::XS->new->utf8;
    $encoder->encode( exists $data->{rest} ? $data->{rest} : $data );
}

1;
