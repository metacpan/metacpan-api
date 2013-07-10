use strict;
use warnings;
use utf8;
use Encode qw( encode is_utf8 FB_CROAK LEAVE_SRC );
use JSON qw( decode_json );
use Test::More;
use MetaCPAN::Server::Test;
BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

test_psgi app, sub {
    my $cb = shift;

    test_pause_auth($cb, 'RWSTAUNER', 'Trouble Maker');
    test_pause_auth($cb, 'NEVERHEARDOFHIM',  "Who?", fail => 1);
    test_pause_auth($cb, 'BORISNAT',  "Лось и Белка");
};

done_testing;

sub test_pause_auth {
    my ($cb, $pause_id, $full_name, %args) = @_;

  subtest _u("PAUSE login email for $pause_id $full_name") => sub {
    my $req = GET("/login/pause?id=$pause_id");
    my $res = $cb->($req);
    my $delivery = Email::Sender::Simple->default_transport->shift_deliveries;
    my $email = $delivery->{email};

    my $body = decode_json($res->content);
    is $res->code, 200, 'GET ok';

    if( $args{fail} ){
        is($body->{error}, 'author_not_found', 'recognize nonexistent author');
        return;
    }

    is $body->{success}, 'mail_sent', 'success';
    ok $email, 'sent email'
        or die explain $res;

    is $email->get_header('to'), "\L$pause_id\@cpan.org", 'To: cpan address';
    like $email->get_header('subject'), qr/\bmetacpan\s.+\sPAUSE\b/i,
        'subject mentions metacpan and pause';

    like $email->get_body, qr/Hi \Q$full_name\E,/,
        'email body mentions verifying pause account';

    like $email->get_body, qr/verify.+\sPAUSE\b/,
        'email body mentions verifying pause account';

    like $email->get_body,
        qr!\shttp://${\ $req->uri->host }${\ $req->uri->path }\?code=\S!m,
        'email body contains uri with code';

    # TODO: figure out what the oauth redirect is supposed to do and test it
  };
}

sub _u {
    my $s = $_[0];
    return is_utf8($s) ? encode('UTF-8', $s, FB_CROAK | LEAVE_SRC) : $s;
}
