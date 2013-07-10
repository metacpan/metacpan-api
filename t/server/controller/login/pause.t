use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;
BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

test_psgi app, sub {
    my $cb = shift;

    test_pause_auth($cb, 'RWSTAUNER', 'Trouble Maker');
};

done_testing;

# TODO: test failure
sub test_pause_auth {
    my ($cb, $pause_id, $full_name) = @_;

    my $req = GET("/login/pause?id=$pause_id");
    my $res = $cb->($req);
    my $delivery = Email::Sender::Simple->default_transport->shift_deliveries;
    my $email = $delivery->{email};

    is $res->code, 200, 'login pause start ok';
    ok $email, 'sent email';

    is $email->get_header('to'), "\L$pause_id\@cpan.org", 'To: cpan address';
    like $email->get_header('subject'), qr/\bmetacpan\s.+\sPAUSE\b/i,
        'subject mentions metacpan and pause';

    like $email->get_body, qr/Hi $full_name,/,
        'email body mentions verifying pause account';

    like $email->get_body, qr/verify.+\sPAUSE\b/,
        'email body mentions verifying pause account';

    like $email->get_body,
        qr!\shttp://${\ $req->uri->host }${\ $req->uri->path }\?code=\S!m,
        'email body contains uri with code';

    # TODO: figure out what the oauth redirect is supposed to do and test it
};
