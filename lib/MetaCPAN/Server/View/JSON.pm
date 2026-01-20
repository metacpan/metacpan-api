package MetaCPAN::Server::View::JSON;

use strict;
use warnings;

use Cpanel::JSON::XS ();
use Moose;

extends 'Catalyst::View::JSON';

sub encode_json {
    my ( $self, $c, $data ) = @_;
    my $encoder
        = $c->req->looks_like_browser
        ? Cpanel::JSON::XS->new->utf8->allow_blessed->canonical->pretty
        : Cpanel::JSON::XS->new->utf8->allow_blessed->canonical;
    $encoder->encode( exists $data->{rest} ? $data->{rest} : $data );
}

1;
