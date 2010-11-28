package Plack::Middleware::CPANSource;

use parent qw( Plack::Middleware );

use Data::Dump qw( dump );
use Modern::Perl;
 
sub call {
    my($self, $env) = @_;
    # Do something with $env
 
    say dump( $env ); 
    # $self->app is the original app
    my $res = $self->app->($env);
 
    # Do something with $res
    return $res;
}

1;
