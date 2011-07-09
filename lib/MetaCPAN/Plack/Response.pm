package MetaCPAN::Plack::Response;
use strict;
use warnings;
use base 'Plack::Response';

use JSON::XS;
use Plack::Util::Accessor qw(request);

sub _body {
    my $self = shift;
    my $body = $self->body;
    return [] unless defined $body;
    if(ref $body eq 'HASH') {
        return $self->request && $self->request->looks_like_browser
            ? [JSON::XS->new->utf8->pretty->encode($body)]
            : [encode_json($body)];
    } else {
        return $self->SUPER::_body(@_);
    }
}

sub finalize {
    my $self = shift;
    unless($self->headers->as_string) {
        $self->headers([$self->_headers])
    }
    return $self->SUPER::finalize(@_);
}

sub _headers {
    return (
        'Access-Control-Allow-Origin',      'http://localhost:3030',
        'Access-Control-Allow-Headers',     'X-Requested-With, Content-Type',
        'Access-Control-Allow-Methods',     'POST',
        'Access-Control-Max-Age',           '17000000',
        'Access-Control-Allow-Credentials', 'true',
        'Content-type',                     'application/json; charset=UTF-8' );
}


1;