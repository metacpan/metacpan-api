package MetaCPAN::Server::Controller::Login::PAUSE;

use Moose;
use namespace::autoclean;

use MetaCPAN::Model::Email::PAUSE   ();
use MetaCPAN::Model::PAUSELinkToken ();
use MetaCPAN::Util                  qw( true );

BEGIN { extends 'MetaCPAN::Server::Controller::Login' }

# The emailed token is signed and names the requesting account, so any API
# instance can verify it without shared storage.
has tokens => (
    is      => 'ro',
    isa     => 'MetaCPAN::Model::PAUSELinkToken',
    lazy    => 1,
    builder => '_build_tokens',
);

sub _build_tokens {
    my $self   = shift;
    my $secret = $self->_application->config->{pause_link_secret};
    die "pause_link_secret is not configured\n"
        unless defined $secret && length $secret;
    return MetaCPAN::Model::PAUSELinkToken->new( secret => $secret );
}

sub index : Path Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->params;

    if ( defined $params->{code} ) {
        $self->_confirm( $c, $params->{code} );
    }
    elsif ( defined $params->{id} && $params->{id} =~ /[a-zA-Z]/ ) {
        $self->_send_email( $c, $params->{id} );
    }
    $self->_error( $c, 'invalid_request' );
}

# Step 1: the logged-in user names a PAUSE ID. Mail a link that only this
# account can use.
sub _send_email {
    my ( $self, $c, $id ) = @_;

    # PAUSE is not a login, so the identity needs an account to attach to.
    $self->_error( $c, 'not_logged_in' ) unless $c->user_exists;

    my $author
        = $c->model('ESQuery')->author->by_ids( [$id] )->{authors}->[0];
    $self->_error( $c, 'author_not_found' ) unless $author;

    my $url = $c->request->uri->clone;
    $url->query_form(
        code => $self->tokens->issue(
            pauseid => $author->{pauseid},
            account => $c->user->id,
        )
    );

    my $sent = MetaCPAN::Model::Email::PAUSE->new(
        author => $author,
        url    => $url,
    )->send;

    # Not Log::Contextual: only the scripts call set_logger.
    $c->log->error( 'Could not send PAUSE email to ' . $author->{pauseid} )
        unless $sent;

    $c->controller('OAuth2')->redirect( $c, success => 'mail_sent' );
}

# Step 2: accept the emailed link only from the account that asked for it, so
# any other open (a mail scanner, a forwarded link) changes nothing.
sub _confirm {
    my ( $self, $c, $code ) = @_;

    my $claim = $self->tokens->verify($code);
    $self->_error( $c, $claim->{error} ) if $claim->{error};

    $self->_error( $c, 'not_logged_in' ) unless $c->user_exists;
    $self->_error( $c, 'pause_link_wrong_account' )
        unless $c->user->id eq $claim->{account};

    $self->_link( $c, $c->user->obj, $claim->{pauseid} );
    $self->finish_login( $c, $c->user->obj );
}

# Control of the PAUSE email is the proof that attached the identity to any
# other holder, so the same proof moves it to this account.
sub _link {
    my ( $self, $c, $user, $pauseid ) = @_;
    my $model = $c->model('ESModel')->doc('account');

    my $holder = $model->find( { name => 'pause', key => $pauseid } );
    return if $holder && $holder->id eq $user->id;

    if ($holder) {
        $c->log->info( "Moving PAUSE identity $pauseid from account "
                . $holder->id
                . ' to account '
                . $user->id );
        $holder->remove_identity( 'pause', $pauseid );
        $holder->put( { refresh => true } );
    }

    $user->add_identity( { name => 'pause', key => $pauseid, extra => {} } );
    $user->put(          { refresh => true } );
}

sub _error {
    my ( $self, $c, $error ) = @_;
    $c->controller('OAuth2')->redirect( $c, error => $error );
}

1;
