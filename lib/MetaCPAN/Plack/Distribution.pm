package MetaCPAN::Plack::Distribution;
use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;

sub index { 'distribution' }

sub handle {
    my ($self, $env) = @_;
    return Plack::App::Proxy->new( remote => "http://127.0.0.1:9200/cpan/distribution" )
      ->to_app->($env);
}


1;