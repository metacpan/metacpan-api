package MetaCPAN::Server::View::JSON;

use strict;
use warnings;

use Cpanel::JSON::XS;
use Moose;

extends 'Catalyst::View::JSON';

no warnings 'redefine';

sub encode_json($) {
    my ( $self, $c, $data ) = @_;
    my $encoder
        = $c->req->looks_like_browser
        ? Cpanel::JSON::XS->new->utf8->pretty
        : Cpanel::JSON::XS->new->utf8;
    $encoder->encode( exists $data->{rest} ? $data->{rest} : $data );
}

1;
