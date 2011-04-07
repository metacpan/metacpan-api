package MetaCPAN::Plack::Distribution;
use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;

sub index { 'distribution' }

sub handle {
    my ($self, $env) = @_;
    $self->get_source($env);
}


1;