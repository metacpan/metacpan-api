package MetaCPAN::Plack::Release;
use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;

sub index { 'release' }

sub handle {
    my ($self, $env) = @_;
    $self->get_source($env);
}


1;