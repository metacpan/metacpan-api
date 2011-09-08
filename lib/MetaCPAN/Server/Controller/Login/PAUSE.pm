package MetaCPAN::Server::Controller::Login::PAUSE;

use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller::Login' }
use JSON;
use Email::Sender::Simple ();
use Email::Simple         ();
use CHI                   ();
use Digest::SHA1          ();

has cache => ( is => 'ro', builder => '_build_cache' );

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
        my $code = $self->generate_sid;
        $self->cache->set( $code, $author->pauseid, 86400 );
        my $uri = $c->request->uri->clone;
        $uri->query("code=$code");
        my $email = Email::Simple->create(
            header => [
                'Content-Type' => 'text/plain; charset=utf-8',
                To             => $author->{email}->[0],
                From           => 'noreply@metacpan.org',
                Subject        => "Connect MetaCPAN with your PAUSE account",
                'MIME-Version' => 1.0,
            ],
            body => qq{Hi ${\$author->name},

please click on the following link to verify your PAUSE account:

$uri

Cheers,
MetaCPAN
}
        );
        Email::Sender::Simple->send($email);
        $c->controller('OAuth2')->redirect( $c, success => "mail_sent" );
    }
}

sub generate_sid {
    Digest::SHA1::sha1_hex( rand() . $$ . {} . time );
}

1;
