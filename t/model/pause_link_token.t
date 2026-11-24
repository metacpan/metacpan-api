use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS qw( encode_json );
use Digest::SHA      qw( hmac_sha256 );
use MIME::Base64     qw( encode_base64url );
use Test::Fatal      qw( exception );
use Test::More;

use_ok('MetaCPAN::Model::PAUSELinkToken');

my $secret = 'x' x 32;
my $now    = 1_700_000_000;
my $tokens = MetaCPAN::Model::PAUSELinkToken->new( secret => $secret );

sub issue {
    $tokens->issue( pauseid => 'FOO', account => 'acct-1', now => $now, @_ );
}

subtest 'new' => sub {
    like exception {
        MetaCPAN::Model::PAUSELinkToken->new( secret => 'x' x 31 )
    }, qr/at least 32/, 'a 31-character secret is refused';
    ok !exception {
        MetaCPAN::Model::PAUSELinkToken->new( secret => 'x' x 32 )
    }, 'a 32-character secret is accepted';
};

subtest 'issue' => sub {
    like issue(), qr/\A[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\z/,
        'token is URL-safe without escaping';
    like exception { $tokens->issue( account => 'acct-1' ) },
        qr/pauseid is required/, 'refuses a token with no PAUSE ID';
    like exception { $tokens->issue( pauseid => 'FOO', account => '' ) },
        qr/account is required/, 'refuses a token with an empty account';
};

subtest 'verify: a good token' => sub {
    is_deeply $tokens->verify( issue(), now => $now ),
        { pauseid => 'FOO', account => 'acct-1' },
        'returns the PAUSE ID and the account it was issued for';

    my $other = MetaCPAN::Model::PAUSELinkToken->new( secret => $secret );
    is_deeply $other->verify( issue(), now => $now ),
        { pauseid => 'FOO', account => 'acct-1' },
        'another instance with the same secret accepts it (no shared state)';

    is_deeply $tokens->verify( issue(), now => $now + 1 ),
        { pauseid => 'FOO', account => 'acct-1' },
        'using it does not consume it, so a prefetch cannot spend it';
};

subtest 'verify: expiry boundary' => sub {
    my $ttl = $tokens->ttl;
    ok !$tokens->verify( issue(), now => $now + $ttl )->{error},
        'still valid at exactly the expiry second';
    is $tokens->verify( issue(), now => $now + $ttl + 1 )->{error},
        'pause_link_expired', 'expired one second later';
};

subtest 'verify: forged or damaged tokens' => sub {
    my $token = issue();
    my ( $payload, $mac ) = split /\./, $token;

    my $forged = encode_base64url(
        encode_json( { p => 'FOO', a => 'attacker', e => $now + 86400 } ) );

    my %bad = (
        'undef'              => undef,
        'empty string'       => q{},
        'no dot'             => $payload,
        'two dots'           => "$payload.$mac.$mac",
        'bytes outside b64u' => "$payload.$mac=",
        'payload swapped'    => "$forged.$mac",
        'mac changed'        => $payload . '.' . reverse($mac),
        'mac truncated'      => $payload . '.' . substr( $mac, 1 ),
        'other secret'       => MetaCPAN::Model::PAUSELinkToken->new(
            secret => 'y' x 32
        )->issue( pauseid => 'FOO', account => 'acct-1', now => $now ),
        'mac without purpose' => "$payload."
            . encode_base64url( hmac_sha256( $payload, $secret ) ),
    );

    for my $case ( sort keys %bad ) {
        is $tokens->verify( $bad{$case}, now => $now )->{error},
            'pause_link_invalid', "$case: refused as invalid";
    }
};

subtest 'verify: well-signed but malformed claims' => sub {
    my $sign = sub {
        my $payload = encode_base64url(shift);
        $payload . '.'
            . encode_base64url(
            hmac_sha256( "metacpan-pause-link-v1\0$payload", $secret ) );
    };

    is $tokens->verify( $sign->('not json'), now => $now )->{error},
        'pause_link_invalid', 'payload that is not JSON';
    is $tokens->verify( $sign->('[1,2,3]'), now => $now )->{error},
        'pause_link_invalid', 'payload that is not an object';
    is $tokens->verify( $sign->( encode_json( { p => 'FOO', e => $now } ) ),
        now => $now )->{error}, 'pause_link_invalid',
        'payload with no account';
};

done_testing;
