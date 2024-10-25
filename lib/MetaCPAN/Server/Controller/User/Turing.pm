package MetaCPAN::Server::Controller::User::Turing;

use strict;
use warnings;

use DateTime ();
use Moose;
use MetaCPAN::Util qw( true false );

BEGIN { extends 'Catalyst::Controller::REST' }

has private_key => (
    is       => 'ro',
    required => 1,
);

has captcha_class => (
    is      => 'ro',
    default => 'Captcha::reCAPTCHA',
);

sub index : Path : ActionClass('REST') {
}

sub index_POST {
    my ( $self, $c ) = @_;
    my $user    = $c->user->obj;
    my $captcha = $self->captcha_class->new;
    my $result
        = $captcha->check_answer_v2( $self->private_key,
        $c->req->data->{answer},
        $c->req->address, );

    if ( $result->{is_valid} ) {
        $user->_set_passed_captcha( DateTime->now );
        $user->clear_looks_human;    # rebuild
        $user->put( { refresh => true } );
        $self->status_ok( $c, entity => $user->meta->get_data($user) );
    }
    else {
        $self->status_bad_request( $c, message => $result->{error} );
    }
}

1;
