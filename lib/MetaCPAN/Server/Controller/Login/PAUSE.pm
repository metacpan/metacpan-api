package MetaCPAN::Server::Controller::Login::PAUSE;

use strict;
use warnings;
use namespace::autoclean;

use CHI                   ();
use Email::Sender::Simple ();
use Email::Simple         ();
use Encode                ();
use JSON;
use Moose;
use Try::Tiny;
use MetaCPAN::Util;

BEGIN { extends 'MetaCPAN::Server::Controller::Login' }

has cache => (
    is      => 'ro',
    builder => '_build_cache',
);

sub _build_cache {
    CHI->new(
        driver   => 'File',
        root_dir => 'var/tmp/cache',
    );
}

sub index : Path {
    my ( $self, $c ) = @_;
    my $code = $c->req->params->{code};
    my $id;
    if ( $code
        && ( $id = $self->cache->get($code) ) )
    {
        $self->cache->remove($code);
        $self->update_user( $c, pause => $id, {} );

    }
    elsif ( ( $id = $c->req->parameters->{id} )
        && $c->req->parameters->{id} =~ /[a-zA-Z]+/ )
    {
        my $author = $c->model('CPAN::Author')->get( uc($id) );
        $c->controller('OAuth2')->redirect( $c, error => "author_not_found" )
            unless ($author);
        my $code = MetaCPAN::Util::generate_sid;
        $self->cache->set( $code, $author->pauseid, 86400 );
        my $uri = $c->request->uri->clone;
        $uri->query("code=$code");
        my $email = Email::Simple->create(
            header => [
                'Content-Type' => 'text/plain; charset=utf-8',
                To             => $author->{email}->[0],
                From           => 'noreply@metacpan.org',
                Subject        => "Connect MetaCPAN with your PAUSE account",
                'MIME-Version' => '1.0',
            ],
            body => $self->email_body( $author->name, $uri ),
        );
        Email::Sender::Simple->send($email);
        $c->controller('OAuth2')->redirect( $c, success => "mail_sent" );
    }
}

sub email_body {
    my ( $self, $name, $uri ) = @_;

    my $body = <<EMAIL_BODY;
Hi ${name},

please click on the following link to verify your PAUSE account:

$uri

Cheers,
MetaCPAN
EMAIL_BODY

    try {
        $body = Encode::encode( 'UTF-8', $body,
            Encode::FB_CROAK | Encode::LEAVE_SRC );
    }
    catch {
        warn $_[0];
    };

    return $body;
}

1;
