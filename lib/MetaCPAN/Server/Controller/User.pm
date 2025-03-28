package MetaCPAN::Server::Controller::User;

use strict;
use warnings;

use DateTime       ();
use MetaCPAN::Util qw( true false );
use Moose;
use Log::Log4perl::MDC ();

BEGIN { extends 'Catalyst::Controller::REST' }

with 'MetaCPAN::Role::Fastly';

__PACKAGE__->config(
    json_options => { relaxed => 1, allow_nonref => 1 },
    default      => 'text/html',
    map          => { 'text/html' => [qw(View JSON)] },
);

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->cdn_never_cache(1);

    if ( my $token = $c->req->params->{access_token} ) {
        if ( my $user
            = $c->model('ESModel')->doc('account')->find_token($token) )
        {
            $c->authenticate( { user => $user } );
            Log::Log4perl::MDC->put( user => $user->id );
        }
    }
    return $c->user_exists;
}

sub index : Path Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( $c->user->data );
    delete $c->stash->{code};
    $c->detach( $c->view('JSON') );
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
        : $self->status_not_found( $c, message => 'Identity doesn\'t exist' );
}

sub identity_DELETE {
    my ( $self, $c ) = @_;
    my ($identity) = @{ $c->req->arguments };
    my $user = $c->user;
    if ( $user->has_identity($identity) ) {
        my $id = $user->remove_identity($identity);
        $user->put( { refresh => true } );
        $self->status_ok( $c, entity => $id );
    }
    else {
        $self->status_not_found( $c, message => 'Identity doesn\'t exist' );
    }
}

sub profile : Local : ActionClass('REST') {
    my ( $self, $c ) = @_;
    my ($pause) = $c->user->get_identities('pause');
    unless ($pause) {
        $self->status_not_found( $c, message => 'Profile doesn\'t exist' );
        $c->detach;
    }
    my $profile
        = $c->model('ESModel')->doc('author')->raw->get( $pause->key );
    $c->stash->{profile} = $profile->{_source};
}

sub profile_GET {
    my ( $self, $c ) = @_;
    $self->status_ok( $c, entity => $c->stash->{profile} );
}

sub profile_PUT {
    my ( $self, $c ) = @_;
    my $profile = $c->stash->{profile};

    map {
        defined $c->req->data->{$_}
            ? $profile->{$_} = $c->req->data->{$_}
            : delete $profile->{$_}
        } qw(name asciiname website email
        gravatar_url profile blog
        donation city region country
        location extra perlmongers);
    $profile->{updated} = DateTime->now->iso8601;
    my @errors = $c->model('ESModel')->doc('author')
        ->new_document->validate($profile);

    if (@errors) {
        $self->status_bad_request( $c, message => 'Validation failed' );
        $c->stash->{rest}->{errors} = \@errors;
    }
    else {
        $profile
            = $c->model('ESModel')->doc('author')
            ->put( $profile, { refresh => true } );
        $self->status_created(
            $c,
            location => $c->uri_for( '/author/' . $profile->{pauseid} ),
            entity   => $profile->meta->get_data($profile)
        );
        $self->purge_author_key( $profile->{pauseid} );
    }

}

1;
