use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;
use Sub::Override;

test_psgi app, sub {
    my $cb = shift;

    test_pause_auth($cb, 'RWSTAUNER', 'Trouble Maker');
};

done_testing;

# TODO: test failure
sub test_pause_auth {
    my ($cb, $pause_id, $full_name) = @_;

    my $email;
    my $over = Sub::Override->new('Email::Sender::Simple::send' => sub { $email = $_[1]; });

    my $req = GET("/login/pause?id=$pause_id");
    my $res = $cb->($req);

    is $res->code, 200, 'login pause start ok';
    ok $email, 'sent email';

    is $email->header('to'), "\L$pause_id\@cpan.org", 'To: cpan address';
    like $email->header('subject'), qr/\bmetacpan\s.+\sPAUSE\b/i,
        'subject mentions metacpan and pause';

    like $email->body, qr/Hi $full_name,/,
        'email body mentions verifying pause account';

    like $email->body, qr/verify.+\sPAUSE\b/,
        'email body mentions verifying pause account';

    like $email->body,
        qr!\shttp://${\ $req->uri->host }${\ $req->uri->path }\?code=\S!m,
        'email body contains uri with code';

    # TODO: figure out what the oauth redirect is supposed to do and test it
};
