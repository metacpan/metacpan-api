package MetaCPAN::Model::PAUSELinkToken;

use Moose;
use namespace::autoclean;

use Cpanel::JSON::XS qw( decode_json encode_json );
use Digest::SHA      qw( hmac_sha256 );
use MIME::Base64     qw( decode_base64url encode_base64url );
use Try::Tiny        qw( try );

=head1 NAME

MetaCPAN::Model::PAUSELinkToken - Signed token for linking a PAUSE ID

=head1 SYNOPSIS

    my $tokens = MetaCPAN::Model::PAUSELinkToken->new(
        secret => $config->{pause_link_secret},
    );

    my $token = $tokens->issue(
        pauseid => 'FOO',
        account => $c->user->id,
    );

    my $claim = $tokens->verify($token);
    if ( my $error = $claim->{error} ) { ... }

=head1 DESCRIPTION

The link in the PAUSE verification email carries one of these tokens. The
token holds the PAUSE ID, the ID of the MetaCPAN account that asked for the
link, and an expiry time, and an HMAC-SHA256 over all three.

The token needs no storage on the server, so any API instance can verify it,
and a restart does not lose it. Because it names the requesting account, a
caller must also check that the account in the token is the logged-in user.
This class only checks the signature and the expiry.

=cut

# The purpose string goes into every MAC, so a MAC made for some other use of
# the same secret can never verify here.
my $PURPOSE = 'metacpan-pause-link-v1';

has secret => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

# 24 hours -- keep in sync with the expiry mentioned in the email copy in
# MetaCPAN::Model::Email::PAUSE::_email_body.
has ttl => (
    is      => 'ro',
    isa     => 'Int',
    default => 86400,
);

sub BUILD {
    my $self = shift;
    die "PAUSE link secret must be at least 32 characters\n"
        if length $self->secret < 32;
}

=head1 METHODS

=head2 issue( pauseid => $id, account => $account_id, now => $time )

Returns a URL-safe token string. C<now> defaults to the current time.

=cut

sub issue {
    my ( $self, %args ) = @_;
    for my $field (qw( pauseid account )) {
        die "$field is required\n"
            unless defined $args{$field} && length $args{$field};
    }

    my $payload = encode_base64url( encode_json( {
        p => $args{pauseid},
        a => $args{account},
        e => ( $args{now} // time ) + $self->ttl,
    } ) );

    return $payload . '.' . $self->_mac($payload);
}

=head2 verify( $token, now => $time )

Returns C<{ pauseid =E<gt> ..., account =E<gt> ... }> for a good token, or
C<{ error =E<gt> 'pause_link_invalid' }> or
C<{ error =E<gt> 'pause_link_expired' }>.

=cut

sub verify {
    my ( $self, $token, %args ) = @_;
    my $invalid = { error => 'pause_link_invalid' };

    return $invalid unless defined $token;
    my ( $payload, $mac )
        = $token =~ /\A([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)\z/
        or return $invalid;

    return $invalid unless _equal( $mac, $self->_mac($payload) );

    my $claim = try { decode_json( decode_base64url($payload) ) };
    return $invalid
        unless ref $claim eq 'HASH'
        && defined $claim->{p}
        && defined $claim->{a}
        && defined $claim->{e};

    return { error => 'pause_link_expired' }
        if ( $args{now} // time ) > $claim->{e};

    return { pauseid => $claim->{p}, account => $claim->{a} };
}

# Signs the payload as encoded, so verify() decodes nothing untrusted before
# the check, and base64url-encodes the 32-byte binary digest for the URL.
sub _mac {
    my ( $self, $payload ) = @_;
    return encode_base64url(
        hmac_sha256( "$PURPOSE\0$payload", $self->secret ) );
}

# Unlike eq, this reads every byte after a mismatch, so the time to reject a
# forged MAC does not reveal how many of its leading bytes were correct.
sub _equal {
    my ( $x, $y ) = @_;
    return 0 unless length $x == length $y;
    my $diff = 0;
    $diff |= ord( substr $x, $_, 1 ) ^ ord( substr $y, $_, 1 )
        for 0 .. length($x) - 1;
    return $diff == 0;
}

__PACKAGE__->meta->make_immutable;
1;
