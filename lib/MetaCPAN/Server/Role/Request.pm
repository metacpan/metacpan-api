package MetaCPAN::Server::Role::Request;

use Moose::Role;

around [qw(content_type header)] => sub {
    my ($orig, $self) = (shift,shift);
    my $header = $self->$orig(@_);
    return unless($header);
    return $header =~ /^application\/x-www-form-urlencoded/ ? 'application/json' : $header;
};

1;
