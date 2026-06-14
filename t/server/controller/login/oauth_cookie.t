use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( app GET test_psgi );
use Test::More;

# The `oauth_tmp` cookie carries the OAuth params from the leg that starts the
# flow to the leg that finishes it (the provider callback). When those legs land
# on different *.metacpan.org hosts a host-only cookie is lost and login
# silently fails, so the cookie domain is configurable via `oauth_cookie_domain`
# (set to the shared parent domain in production). We ship a sane default and
# allow it to be overridden -- or disabled (host-only) with an empty value.

test_psgi app, sub {
    my $cb = shift;

    subtest 'applies the cookie domain from config' => sub {
        my $domain = MetaCPAN::Server->config->{oauth_cookie_domain};
        ok defined $domain && length $domain,
            'a default oauth_cookie_domain is configured';

        my $res = $cb->( GET '/login/github?client_id=metacpan.dev' );
        like $res->header('Set-Cookie'), qr/oauth_tmp=/,
            'oauth_tmp cookie set';
        like $res->header('Set-Cookie'), qr/domain=\Q$domain\E/i,
            "Set-Cookie carries the configured domain ($domain)";
    };

    subtest 'config override is honored' => sub {
        my $config = MetaCPAN::Server->config;
        local $config->{oauth_cookie_domain} = '.example.test';

        my $res = $cb->( GET '/login/github?client_id=metacpan.dev' );
        like $res->header('Set-Cookie'), qr/domain=\.example\.test/i,
            'overridden domain applied';
    };

    subtest 'empty oauth_cookie_domain disables the domain (host-only)' =>
        sub {
        my $config = MetaCPAN::Server->config;
        local $config->{oauth_cookie_domain} = q{};

        my $res = $cb->( GET '/login/github?client_id=metacpan.dev' );
        unlike $res->header('Set-Cookie'), qr/domain=/i,
            'no Domain attribute when explicitly disabled';
        };
};

done_testing;
