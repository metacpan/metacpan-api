package MetaCPAN::Plack::Distribution;
use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;

sub type { 'distribution' }

sub handle {
    my ($self, $env) = @_;
    $self->get_source($env);
}


1;