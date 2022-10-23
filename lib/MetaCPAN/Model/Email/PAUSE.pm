package MetaCPAN::Model::Email::PAUSE;

use MetaCPAN::Moose;

use Email::Sender::Simple          qw( sendmail );
use Email::Sender::Transport::SMTP ();
use Email::Simple                  ();
use Encode                         ();
use MetaCPAN::Types::TypeTiny      qw( Object Uri );
use Try::Tiny                      qw( catch try );

with('MetaCPAN::Role::HasConfig');

has _author => (
    is       => 'ro',
    isa      => Object,
    init_arg => 'author',
    required => 1,
);

has _url => (
    is       => 'ro',
    isa      => Uri,
    init_arg => 'url',
    required => 1,
);

sub send {
    my $self = shift;

    my $email = Email::Simple->create(
        header => [
            'Content-Type' => 'text/plain; charset=utf-8',
            To             => $self->_author->{email}->[0],
            From           => 'notifications@metacpan.org',
            Subject        => 'Connect MetaCPAN with your PAUSE account',
            'MIME-Version' => '1.0',
        ],
        body => $self->_email_body,
    );

    my $config    = $self->config->{smtp};
    my $transport = Email::Sender::Transport::SMTP->new(
        {
            debug         => 1,
            host          => $config->{host},
            port          => $config->{port},
            sasl_username => $config->{username},
            sasl_password => $config->{password},
            ssl           => 1,
        }
    );

    my $success = 0;
    try {
        $success = sendmail( $email, { transport => $transport } );
    }
    catch {
        warn 'Could not send message: ' . $_;
    };

    return $success;
}

sub _email_body {
    my $self = shift;
    my $name = $self->_author->name;
    my $uri  = $self->_url;

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
