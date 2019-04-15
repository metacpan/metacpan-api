package MetaCPAN::Server::Controller::Login::PAUSE;

use strict;
use warnings;
use namespace::autoclean;

use CHI ();
use Log::Contextual qw( :log :dlog );
use Moose;
use Try::Tiny qw( catch try );
use MetaCPAN::Model::Email::PAUSE ();
use MetaCPAN::Util qw( generate_sid );

BEGIN { extends 'MetaCPAN::Server::Controller::Login' }

has cache => (
    is      => 'ro',
    isa     => 'CHI::Driver',
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

        my $code = generate_sid();
        $self->cache->set( $code, $author->pauseid, 86400 );

        my $url = $c->request->uri->clone;
        $url->query("code=$code");

        my $email = MetaCPAN::Model::Email::PAUSE->new(
            author => $author,
            url    => $url,
        );

        my $sent = $email->send;

        if ( !$sent ) {
            log_error { 'Could not send PAUSE email to ' . $author->pauseid };
        }

        $c->controller('OAuth2')->redirect( $c, success => 'mail_sent' );
    }
}

1;
