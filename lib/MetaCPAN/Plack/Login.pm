package MetaCPAN::Plack::Login;
use strict;
use warnings;
use base 'MetaCPAN::Plack::Base';
use Class::MOP;
use Module::Find;

my @found = Module::Find::findallmod(__PACKAGE__);

sub call {
    my ( $self, $env ) = @_;
    my $urlmap = Plack::App::URLMap->new;
    $urlmap->map( "/" => sub { $self->choose(shift) } );
    foreach my $class (@found) {
        ( my $short = $class ) =~ s/^.*::(.*?)$/$1/;
        $short = lc($short);
        warn $class;
        Class::MOP::load_class($class);
        $urlmap->map( "/$short" => $class->new( model => $self->model )->to_app );
    }
    return $urlmap->to_app->($env);
}

sub success {
    return [200, ['Content-type', 'application/json'], ['{"success":true,"message":"user has been logged in"}']];

}

sub save_identity {
    my ( $self, $env, $key, $extra ) = @_;

    my $session = $env->{'psgix.session'};
    if ( defined $key ) {
        my $res = $self->model->es->search(
            index  => 'user',
            type   => 'account',
            query  => { match_all => {} },
            filter => {
                and => [
                    { term => { 'user.account.identity.name' => $self->type } },
                    { term => { 'user.account.identity.key'  => $key } } ]
            },
            size => 1, );
        $session = $res->{hits}->{hits}->[0] if ( $res->{hits}->{total} );
    }

    my $ids = $session->{identity} || [];
    $ids = [$ids] unless ( ref $ids eq 'ARRAY' );
    if ( defined $key ) {
        @$ids = grep {
            $_->{name} ne $self->type
              || ( $_->{name} eq $self->type && $_->{key} ne $key )
        } @$ids;
    } else {
        @$ids = grep { $_->{name} ne $self->type } @$ids;
    }
    push( @$ids,
          {  name => $self->type,
             key  => $key || undef,
             $extra ? ( extra => $extra ) : () } );
    $session->{identity} = $ids;
}

sub choose {
    my ( $self, $env ) = @_;
    my $html = "<pre><h1>Login via</h1>";
    for (@found) {
        ( my $short = $_ ) =~ s/^.*::(.*?)$/$1/;
        $short = lc($short);
        $html .= "<li><a href=\"/login/$short\">$_</a></li>";
    }
    $html .= "</pre>";
    return [ 200, [ 'Content-type', 'text/html' ], [$html] ];
}

1;
