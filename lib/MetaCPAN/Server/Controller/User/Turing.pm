package MetaCPAN::Server::Controller::User::Turing;

use Moose;
use Captcha::ReCAPTCHA;
use DateTime;
BEGIN { extends 'Catalyst::Controller::REST' }

has private_key   => ( is => 'ro', required => 1 );
has captcha_class => ( is => 'ro', default  => 'Captcha::reCAPTCHA' );

sub index : Path : ActionClass('REST') {
}

sub index_POST {
    my ( $self, $c ) = @_;
    my $user    = $c->user->obj;
    my $captcha = $self->captcha_class->new;
    my $result  = $captcha->check_answer(
        $self->private_key,         $c->req->address,
        $c->req->data->{challenge}, $c->req->data->{answer},
    );

    if ( $result->{is_valid} ) {
        $user->passed_captcha( DateTime->now );
        $user->clear_looks_human;    # rebuild
        $user->put( { refresh => 1 } );
        $self->status_ok( $c, entity => $user->meta->get_data($user) );
    }
    else {
        $self->status_bad_request( $c, message => $result->{error} );
    }
}

1;
