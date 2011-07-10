package MetaCPAN::Server::Controller::User;

use Moose;
BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    json_options => { relaxed => 1, allow_nonref => 1 },
    default      => 'text/html',
    map => { 'text/html' => [qw(View JSON)] }
);

sub auto : Private {
    my ( $self, $c ) = @_;
    if ( my $token = $c->req->params->{access_token} ) {
        my $user = $c->model('User::Account')->find_token($token);
        $c->authenticate( { user => $user } ) if ($user);
    }
    return $c->user_exists;
}

sub index : Path {
    my ( $self, $c ) = @_;
    $c->stash( $c->user->data );
}

sub identity : Local : ActionClass('REST') {
}

sub identity_GET {
    my ( $self, $c ) = @_;
    my ($identity) = @{ $c->req->arguments };
    ($identity)
        = grep { $_->{name} eq $identity } @{ $c->user->data->{identity} };
    $identity
        ? $self->status_ok( $c, entity => $identity )
        : $self->status_not_found($c, message => 'Identity doesn\'t exist');
}

sub identity_DELETE {
    my ( $self, $c ) = @_;
    my ($identity) = @{ $c->req->arguments };
    my $ids = $c->user->identity;
    ($identity) = grep { $_->name eq $identity } @$ids;
    if ($identity) {
        @$ids = grep { $_->{name} ne $identity->name } @$ids;
        $c->user->put( { refresh => 1 } );
        $self->status_ok( $c, entity => $identity );
    }
    else {
        $self->status_not_found($c, message => 'Identity doesn\'t exist');
    }
}

1;
