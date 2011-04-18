package MetaCPAN::Plack::Login::GitHub;

use strict;
use warnings;
use base 'MetaCPAN::Plack::Login';

use Plack::App::URLMap;
use Plack::Request;
use Plack::Util::Accessor qw(
  consumer_key
  consumer_secret
);

use OAuth::Lite::Util qw(parse_auth_header);
use OAuth::Lite::ServerUtil;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

sub prepare_app {
    my $self = shift;
    $self->consumer_key('a39208917932b111f139');
    $self->consumer_secret('0effb29908273ed7d170aac425aef3226842c2d9');
}

sub login {
    my $self = shift;

    my $body = 'Authorization required';
    return [
          301,
          [ 'Content-Type' => 'text/plain',
            'Location' => 'https://github.com/login/oauth/authorize?client_id='
              . $self->consumer_key,
          ],
          [$body], ];
}

sub call {
    my ( $self, $env ) = @_;
    my $urlmap = Plack::App::URLMap->new;
    $urlmap->map( "/" => sub { $self->login(shift) } );
    $urlmap->map( "/cb"    => sub { $self->validate(shift) } );
    return $urlmap->to_app->($env);
}

sub unauthorized {
    return [ 403, [], ['Access Denied'] ];
}

sub validate {
    my ( $self, $env ) = @_;
    my $req  = Plack::Request->new($env);
    my $code = $req->param('code');
    my $ua   = LWP::UserAgent->new;
    my $res = $ua->request( POST 'https://github.com/login/oauth/access_token',
                            [ client_id     => $self->consumer_key,
                              redirect_uri  => 'http://localhost:5000/login/github/cb',
                              client_secret => $self->consumer_secret,
                              code          => $code,
                            ] );
    if ( $res->content =~ /^error/ ) {
        return $self->unauthorized;
    }
    ( my $token = $res->content ) =~ s/^access_token=//;
    return [ 200, [], [$token] ];
}

1;
