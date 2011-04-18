package MetaCPAN::Plack::User;
use strict;
use warnings;
use base 'MetaCPAN::Plack::Base';


sub call {
    my ( $self, $env ) = @_;
    my $key = $env->{'psgix.session.options'}->{id};
    return $self->no_session unless($key);
    my ($user) = $self->model->index('user')->type('account')->query({
        query => { match_all => {} },
        filter => { term => { session => $key } },
        size => 1,
    })->all;
    return $self->not_found unless($user);
    return [200, [], ['user']];
}

sub not_found {
    return [404, ['Content-type', 'application/json'], ['{"error":"no user account attached to that session"}']];
}

sub no_session {
    return [500, ['Content-type', 'application/json'], ['{"error":"no session was detected"}']];
}

1;