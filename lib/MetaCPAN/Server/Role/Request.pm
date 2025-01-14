package MetaCPAN::Server::Role::Request;

use strict;
use warnings;

use Moose::Role;

around [qw(content_type header)] => sub {
    my ( $orig, $self ) = ( shift, shift );
    my $header = $self->$orig(@_);
    return unless ($header);
    return $header =~ /^application\/x-www-form-urlencoded/
        ? 'application/json'
        : $header;
};

sub fields {
    my $self   = shift;
    my @fields = map { split /,/ } $self->param('fields');
    return @fields ? \@fields : undef;
}

1;
