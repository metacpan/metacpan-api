package MetaCPAN::Plack::Scroll;

use base 'MetaCPAN::Plack::Base';
use JSON::XS;
use strict;
use warnings;

sub handle {
  my ( $self, $req ) = @_;
  if ( $req->path =~ m/^\/_search\/scroll$/ ) {
    my $res = $self->model->es->transport->request({
      method => $req->method,
      qs => $req->parameters->as_hashref,
      cmd => '/_search/scroll',
      data => $req->decoded_body
    });
    return [ 200, [ $self->_headers ], [encode_json($res)] ];
  }
  return $self->not_found;

}

1;
__END__

=head1 METHODS

=head2 handle

Proxy scroll request to ElasticSearch.

=head1 SEE ALSO

L<MetaCPAN::Plack::Base>
