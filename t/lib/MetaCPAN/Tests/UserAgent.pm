use strict;
use warnings;

package MetaCPAN::Tests::UserAgent;

use Test::Routine;
use Test::More;

use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request;

has cb => (
    is       => 'ro',
    required => 1,
);

has responses => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [] },
);

has ua => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        LWP::UserAgent->new(

            # Don't follow redirect since we're not actually listening on
            # localhost:80 (we need to pass to $cb).
            max_redirect => 0,
        );
    },
);

has cookie_jar => (
    is      => 'ro',
    default => sub {
        HTTP::Cookies->new();
    },
);

sub last_response {
    my ($self) = @_;
    $self->responses->[-1];
}

sub redirect_uri {
    my ( $self, $response ) = @_;
    $response ||= $self->last_response;
    return URI->new( $response->header('location') );
}

sub follow_redirect {
    my ( $self, $response ) = @_;
    $response ||= $self->last_response;

    return $self->request( $self->request_from_redirect($response) );
}

sub request_from_redirect {
    my ( $self, $response ) = @_;
    return HTTP::Request->new( GET => $self->redirect_uri($response) );
}

# This can be overridden if tests have better criteria.
sub request_is_external {
    my ( $self, $request ) = @_;

    # If it's a generic URI (no scheme) it was probably "/controller/action".
    return 0 if !$request->uri->scheme;

    # The tests shouldn't interact with a webserver on localhost:80
    # so assume that the request was built without host/port
    # and it was intended for the plack cb.
    return $request->uri->host_port ne 'localhost:80';
}

sub request {
    my ( $self, $request ) = @_;
    my $response;

    # Use UA to request against external servers.
    if ( $self->request_is_external($request) ) {
        $response = $self->ua->request($request);
    }

    # Use the plack test cb for requests against our app.
    else {
        # We need to preserve the cookies so the API knows who we are.
        $self->cookie_jar->add_cookie_header($request);
        $response = $self->cb->($request);
        $self->cookie_jar->extract_cookies($response);
    }

    push @{ $self->responses }, $response;

    return $response;
}

1;
