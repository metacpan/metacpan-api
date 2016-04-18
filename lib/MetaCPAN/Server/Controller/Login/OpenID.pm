package MetaCPAN::Server::Controller::Login::OpenID;

use strict;
use warnings;

use Moose;
use Net::OpenID::Consumer;
use LWP::UserAgent::Paranoid;
use MooseX::ClassAttribute;
use MetaCPAN::Types qw( Str );

BEGIN { extends 'MetaCPAN::Server::Controller::Login' }

class_has '_ua' => (
    is      => 'ro',
    isa     => 'LWP::UserAgent::Paranoid',
    lazy    => 1,
    builder => '_build_ua',
);

sub _build_ua {
    LWP::UserAgent::Paranoid->new(
        protocols_allowed => [ 'http', 'https' ],
        request_timeout   => 10,
        resolver          => Net::DNS::Paranoid->new(),
    );
}

has 'sreg' => (
    is      => 'rw',
    isa     => Str,
    default => 'http://openid.net/extensions/sreg/1.1',
);

sub index : Path {
    my ( $self, $c ) = @_;
    my $claimed_uri = $c->req->params->{openid_identifier};
    my $csr         = Net::OpenID::Consumer->new(
        ua            => $self->_ua,
        required_root => $c->uri_for(q{/}),
        args          => $c->req->params,
        consumer_secret =>
            $c->config->{'Controller::Login::OpenID'}->{secret_key},
        assoc_options => [
            max_encrypt              => 1,
            session_no_encrypt_https => 1,
        ],
    );
    if ($claimed_uri) {
        if ( my $claimed_identity = $csr->claimed_identity("$claimed_uri") ) {
            $claimed_identity->set_extension_args(
                $self->sreg,
                {
                    optional => 'email,fullname',
                },
            );

            my $check_url = $claimed_identity->check_url(
                return_to      => $c->uri_for( $self->action_for('index') ),
                trust_root     => $c->uri_for(q{/}),
                delayed_return => 1,
            );

            $c->res->redirect($check_url);
        }
        else {
            $c->controller('OAuth2')->redirect( $c, error => $csr->err );
        }
    }

    if ( $c->req->params->{'openid.mode'} ) {
        if ( $csr->setup_needed and my $setup_url = $csr->user_setup_url ) {
            $c->res->redirect($setup_url);
        }
        elsif ( $csr->user_cancel ) {
            $c->controller('OAuth2')
                ->redirect( $c, error => 'access denied' );
        }
        elsif ( my $vident = $csr->verified_identity ) {
            my $user_data = $vident->signed_extension_fields( $self->sreg );
            $self->update_user(
                $c,
                openid => $vident->url,
                $user_data,
            );
        }
        else {
            $c->controller('OAuth2')->redirect( $c, error => $csr->err );
        }
    }
}

1;
