package MetaCPAN::Server::Role::Request;

use strict;
use warnings;

use Moose::Role;
use Ref::Util qw( is_arrayref );

around [qw(content_type header)] => sub {
    my ( $orig, $self ) = ( shift, shift );
    my $header = $self->$orig(@_);
    return unless ($header);
    return $header =~ /^application\/x-www-form-urlencoded/
        ? 'application/json'
        : $header;
};

sub read_param {
    my ( $self, $param ) = @_;
    my $params = $self->parameters->{$param};
    return ( is_arrayref $params ? @$params : $params );
}

1;
