package MetaCPAN::Tests::API;
use Moose::Role;
use MetaCPAN::Server::Test;
use Test::More;
use namespace::autoclean;

has cb => (
    is         => 'ro',
    isa        => 'CodeRef',
    builder    => '_build_cb',
);

sub _build_cb {
    my $cb;
    test_psgi app, sub { $cb = shift; };
    return $cb;
}

=head2 request

Call with string of C<GET>, C<POST>, or C<DELETE> to get
functionality like L<HTTP::Request::Common> without having to import it:

  $self->request(GET => "url");

Or just pass in an object:

  use HTTP::Request;
  $self->request(POST("url", @args));
  # or
  $self->request(HTTP::Request->new(@args));

=cut

sub request {
    my ($self, @args) = @_;
    if( @args > 1 && $args[0] =~ /^(GET|POST|DELETE)$/ ){
        my $func = shift @args;
        no strict 'refs';
        @args = "HTTP::Request::Common::$func"->(@args);
    }
    $self->cb->(@args);
}

=head2 request_content

Calls L</request>, tests for a C<200 OK>, and returns the response content.
It will decode the response when appropriate (for example, json).

=cut

sub request_content {
    my $res = shift->request(@_);

    is($res->code, 200, "200 OK: " . $res->request->uri->path)
        # fully qualify these in case Test::Most has been used
        or diag $res->content;

    return decode_json($res->content)
        if $res->content_type =~ /json/;
    return $res->content;
}

1;
