package MetaCPAN::Plack::Request;
use strict;
use warnings;
use base 'Plack::Request';

use Encode;
use URI::Escape;
use HTTP::Headers::Util qw(split_header_words);
use JSON::XS;
use Try::Tiny;

my $CHECK = Encode::FB_CROAK | Encode::LEAVE_SRC;

sub path {
    my $self = shift;
    ($self->{decoded_path}) =
        $self->_decode(URI::Escape::uri_unescape($self->uri->path))
        unless($self->{decoded_path});
    return $self->{decoded_path};
}

sub query_parameters {
    my $self = shift;
    $self->{decoded_query_params} ||= Hash::MultiValue->new(
        $self->_decode($self->uri->query_form)
    );
}

# XXX Consider replacing using env->{'plack.request.body'}?
sub body_parameters {
    my $self = shift;
    $self->{decoded_body_params} ||= Hash::MultiValue->new(
        $self->_decode($self->SUPER::body_parameters->flatten)
    );
}

sub _decode {
    my $enc = shift->headers->content_type_charset || 'UTF-8';
    map { decode $enc, $_, $CHECK } @_;
}

sub clone {
  my ($self, %extra) = @_;
  return (ref $self)->new({ %{$self->env}, %extra });
}

# ripped from Catalyst::TraitFor::Request::REST

{
  my %HTMLTypes = map { $_ => 1 } qw(
    text/html
    application/xhtml+xml
  );

  sub _build_looks_like_browser {
    my $self = shift;

    my $with = $self->header('x-requested-with');
    return 0
      if $with && grep { $with eq $_ } qw( HTTP.Request XMLHttpRequest );

    if ( uc $self->method eq 'GET' ) {
      my $forced_type = $self->param('content-type');
      return 0
        if $forced_type && !$HTMLTypes{$forced_type};
    }

    # IE7 does not say it accepts any form of html, but _does_
    # accept */* (helpful ;)
    return 1
      if $self->accepts('*/*');

    return 1
      if grep { $self->accepts($_) } keys %HTMLTypes;

    return 0
      if @{ $self->accepted_content_types() };

    # If the client did not specify any content types at all,
    # assume they are a browser.
    return 1;
  }
}

sub _build_accepted_content_types {
  my $self = shift;

  my %types;

  # First, we use the content type in the HTTP Request.  It wins all.
  $types{ $self->content_type } = 3
    if $self->content_type;

  if ( $self->method eq "GET" && $self->param('content-type') ) {
    $types{ $self->param('content-type') } = 2;
  }

  # Third, we parse the Accept header, and see if the client
  # takes a format we understand.
  #
  # This is taken from chansen's Apache2::UploadProgress.
  if ( $self->header('Accept') ) {
    my $accept_header = $self->header('Accept');
    my $counter       = 0;

    foreach my $pair ( split_header_words($accept_header) ) {
      my ( $type, $qvalue ) = @{$pair}[ 0, 3 ];
      next if $types{$type};

      # cope with invalid (missing required q parameter) header like:
      # application/json; charset="utf-8"
      # http://tools.ietf.org/html/rfc2616#section-14.1
      unless ( defined $pair->[2] && lc $pair->[2] eq 'q' ) {
        $qvalue = undef;
      }

      unless ( defined $qvalue ) {
        $qvalue = 1 - ( ++$counter / 1000 );
      }

      $types{$type} = sprintf( '%.3f', $qvalue );
    }
  }

  [ sort { $types{$b} <=> $types{$a} } keys %types ];
}

sub preferred_content_type {
  my $self = shift;
  $self->{_accepts} ||= $self->_build_accepted_content_types;
  $self->{_accepts}->[0];

}

sub decoded_body {
    my $self = shift;
    return $self->{_decoded_body} if ( exists $self->{_decoded_body} );
    my @body = $self->env->{'psgi.input'}->getlines;
    $self->{_decoded_body} = try {
        @body ? JSON::XS->new->relaxed->decode( join( '', @body ) ) : undef;
    }
    catch {
        die [
            500,
            [MetaCPAN::Plack::Base->_headers],
            [ encode_json( { message => $_ } ) ] ];
    };
    return $self->{_decoded_body};
}



sub accepts {
  my $self = shift;
  my $type = shift;
  $self->{_accepts} ||= $self->_build_accepted_content_types;
  return grep { $_ eq $type } @{ $self->{_accepts} };
}


1;