use strict;
use warnings;
use lib 't/lib';
use utf8;

use warnings FATAL => 'utf8';

use Unicode::UTF8          qw( encode_utf8 );
use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::Server::User ();
use MetaCPAN::TestHelpers  qw( decode_json_ok );
use MetaCPAN::Util         qw( true );
use Test::More;

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

# The account that the API thinks is logged in, or undef for no session.
# The tests have no way to complete a real GitHub login, so this stands in
# for the session cookie.
our $LOGGED_IN;

{
    no warnings qw( once redefine );
    *MetaCPAN::Server::user_exists = sub { defined $LOGGED_IN };
    my $real_user = MetaCPAN::Server->can('user');
    *MetaCPAN::Server::user = sub {
        my $c = shift;

        # authenticate() also sets the user through this method.
        return $c->$real_user(@_) if @_;
        return undef unless $LOGGED_IN;
        my $user = MetaCPAN::Server::User->new;
        $user->_set_obj($LOGGED_IN);
        return $user;
    };
}

my $accounts = MetaCPAN::Server->model('ESModel')->doc('account');

sub new_account {
    my $account = $accounts->new_document;
    $account->put( { refresh => true } );
    return $accounts->get( $account->id );
}

test_psgi app, sub {
    my $cb = shift;

    local $LOGGED_IN = new_account();
    test_pause_auth( $cb, 'RWSTAUNER',       'Trouble Maker' );
    test_pause_auth( $cb, 'NEVERHEARDOFHIM', 'Who?', fail => 1 );
    test_pause_auth( $cb, 'BORISNAT',        'Лось и Белка' );

    test_request_needs_login($cb);
    test_confirm($cb);
};

subtest 'remove_identity with a key removes only that PAUSE ID' => sub {
    my $authors = MetaCPAN::Server->model('ESModel')->doc('author');
    my $account = new_account();
    $account->add_identity( { name => 'pause', key => $_ } )
        for qw( RWSTAUNER BORISNAT );
    $account->put( { refresh => true } );
    is $authors->get('BORISNAT')->user, $account->id,
        'precondition: the author profile points to the account';

    my $removed = $account->remove_identity( 'pause', 'BORISNAT' );
    is $removed && $removed->{key}, 'BORISNAT',
        'returns the identity that it removed';
    is_deeply [ map { $_->{key} } $account->get_identities('pause') ],
        ['RWSTAUNER'], 'the other PAUSE ID stays on the account';
    ok !defined $authors->get('BORISNAT')->user,
        'the removed author profile no longer points to the account';

    ok !defined $account->remove_identity( 'pause', 'BORISNAT' ),
        'removing a key that is not there returns nothing';

    # Leave the author profiles as other tests expect them.
    $account->remove_identity('pause');
    $account->put( { refresh => true } );
};

done_testing;

sub request_link {
    my ( $cb, $pause_id ) = @_;
    $cb->( GET "/login/pause?id=$pause_id" );
    my $delivery = Email::Sender::Simple->default_transport->shift_deliveries
        or return;
    my ($url)
        = $delivery->{email}->get_body =~ m{(http\S+\?code=[A-Za-z0-9_.-]+)};
    return $url;
}

sub error_of {
    my $res = shift;
    return $res->code == 200 ? decode_json_ok($res)->{error} : undef;
}

sub pause_holder {
    my $pause_id = shift;
    my $holder   = $accounts->find( { name => 'pause', key => $pause_id } );
    return $holder && $holder->id;
}

sub test_request_needs_login {
    my $cb = shift;
    subtest 'asking for a link needs a logged-in account' => sub {
        local $LOGGED_IN;
        my $res = $cb->( GET '/login/pause?id=RWSTAUNER' );
        is error_of($res), 'not_logged_in', 'refused without a session';
        ok !Email::Sender::Simple->default_transport->shift_deliveries,
            'and no email is sent';
    };
}

sub test_confirm {
    my $cb = shift;

    my $requester = new_account();
    my $other     = new_account();
    my $url       = do {
        local $LOGGED_IN = $requester;
        request_link( $cb, 'RWSTAUNER' );
    };
    ok $url, 'got a confirmation link' or return;

    subtest 'links that are refused change nothing' => sub {
        my $before = pause_holder('RWSTAUNER');

        local $LOGGED_IN;
        is error_of( $cb->( GET $url ) ), 'not_logged_in',
            'no session (a mail scanner, another browser)';

        $LOGGED_IN = $other;
        is error_of( $cb->( GET $url ) ), 'pause_link_wrong_account',
            'logged in as an account that did not ask for the link';

        $LOGGED_IN = $requester;
        ( my $forged = $url ) =~ s/code=.{4}/code=AAAA/;
        is error_of( $cb->( GET $forged ) ), 'pause_link_invalid',
            'a damaged token';

        is error_of( $cb->( GET '/login/pause' ) ), 'invalid_request',
            'no code and no id gives an error, not {}';

        is pause_holder('RWSTAUNER'), $before,
            'the PAUSE identity did not move';
    };

    subtest 'the requester can use the link after a refused open' => sub {
        local $LOGGED_IN = $requester;
        my $res = $cb->( GET $url );
        is $res->code, 302, 'redirects after linking'
            or diag $res->content;
        is pause_holder('RWSTAUNER'), $requester->id,
            'the requesting account now holds the PAUSE identity';
    };

    subtest 'a valid link moves the identity from another account' => sub {
        my $url = do {
            local $LOGGED_IN = $other;
            request_link( $cb, 'RWSTAUNER' );
        };

        local $LOGGED_IN = $other;
        is $cb->( GET $url )->code, 302, 'redirects after linking';
        is pause_holder('RWSTAUNER'), $other->id,
            'the identity moved to the account that proved control';
        ok !$accounts->get( $requester->id )->has_identity('pause'),
            'the previous holder no longer has it';
        is(
            MetaCPAN::Server->model('ESModel')
                ->doc('author')
                ->get('RWSTAUNER')
                ->user,
            $other->id, 'the author profile points to the new holder'
        );

        # Leave the author profile as other tests expect it.
        my $holder = $accounts->get( $other->id );
        $holder->remove_identity( 'pause', 'RWSTAUNER' );
        $holder->put( { refresh => true } );
    };
}

sub test_pause_auth {
    my ( $cb, $pause_id, $full_name, %args ) = @_;

    subtest _u("PAUSE login email for $pause_id $full_name") => sub {
        my $req = GET("/login/pause?id=$pause_id");
        my $res = $cb->($req);
        my $delivery
            = Email::Sender::Simple->default_transport->shift_deliveries;
        my $email = $delivery->{email};

        my $body = decode_json_ok($res);
        is $res->code, 200, 'GET ok';

        if ( $args{fail} ) {
            is( $body->{error}, 'author_not_found',
                'recognize nonexistent author' );
            return;
        }

        is $body->{success}, 'mail_sent', 'success';
        ok $email, 'sent email'
            or die explain $res;

        ok !utf8::is_utf8( $email->get_body ),
            'body is octets (no wide characters)';

        # Thanks ANDK!
        is $email->get_header('MIME-Version'), '1.0', 'valid MIME-Version';

        is $email->get_header('to'), "\L$pause_id\@cpan.org",
            'To: cpan address';
        like $email->get_header('subject'), qr/\bmetacpan\s.+\sPAUSE\b/i,
            'subject mentions metacpan and pause';

        like $email->get_body, qr/Hi \Q${\ _u($full_name) }\E,/,
            'email body has user\'s name';

        like $email->get_body, qr/verify.+\sPAUSE\b/,
            'email body mentions verifying pause account';

        like $email->get_body,
            qr!\shttp://${\ $req->uri->host }${\ $req->uri->path }\?code=\S!m,
            'email body contains uri with code';

    };
}

sub _u {
    my $s = $_[0];
    return utf8::is_utf8($s) ? encode_utf8($s) : $s;
}
