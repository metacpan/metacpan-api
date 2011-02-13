package MetaCPAN::Plack::File;
use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;
use MetaCPAN::Util;

sub index { 'file' }

sub query {
    shift;
    my $digest = MetaCPAN::Util::digest(shift, shift, join("/", @_));
    return { query  => { term => { id    => $digest } },
         size   => 1,
         sort   => { date      => { reverse => \1 } } 
         };
}

sub handle {
    my ($self, $env) = @_;
    $self->get_first_result($env);
}

1;