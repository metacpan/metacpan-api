package MetaCPAN::Plack::Base;
use base 'Plack::Component';
use strict;
use warnings;
use JSON::XS;
use Try::Tiny;
use IO::String;
use Plack::App::Proxy;
use Plack::Middleware::BufferedStreaming;
use mro 'c3';

__PACKAGE__->mk_accessors(qw(cpan remote));

# TODO: rewrite to keep streaming.
# just strip json until we hit "hits":
# count open and closed {} and truncate
# when "hits" is done
sub process_chunks {
    my ( $self, $res, $cb ) = @_;
    my $ret;
    $res->(
        sub {
            my $write = shift;

            my $json;
            if ( @$write == 2 ) {
                my @body;

                $ret = [ @$write, \@body ];
                return
                  Plack::Util::inline_object(write => sub { push @body, $_[0] },
                                             close => sub { }, );
            } else {
                $ret = $write;
                return;
            }

        } );
    try {
        my $json = JSON::XS::decode_json( join( "", @{ $ret->[2] } ) );
        my $res = $cb->($json);
        $ret = ref $res eq 'ARRAY' ? $res : [ 200, $ret->[1], [$res] ];
        Plack::Util::header_remove($ret->[1], 'Content-length')
    };
    return $ret;
}

sub get_source {
    my ( $self, $env ) = @_;
    my $res =
      Plack::App::Proxy->new(
                 remote => "http://" . $self->remote . "/cpan/" . $self->index )
      ->to_app->($env);
    $self->process_chunks(
        $res,
        sub {
            if ( !$_[0]->{_source} ) {
                return $self->error404;
            } else {
                JSON::XS::encode_json( $_[0]->{_source} );
            }
        } );

}

sub error404 {
    [ 404, [], ['Not found'] ];
}

sub get_first_result {
    my ( $self, $env ) = @_;
    $self->rewrite_request($env);
    my $res =
      Plack::App::Proxy->new( remote => "http://" . $self->remote . "/cpan" )
      ->to_app->($env);
    $self->process_chunks(
        $res,
        sub {
            if ( $_[0]->{hits}->{total} == 0 ) {
                return $self->error404;
            } else {
                JSON::XS::encode_json( $_[0]->{hits}->{hits}->[0]->{_source} );
            }
        } );
}

sub rewrite_request {
    my ( $self, $env ) = @_;
    my ( undef, @args ) = split( "/", $env->{PATH_INFO} );
    my $path = '/' . $self->index . '/_search';
    $env->{REQUEST_METHOD} = 'GET';
    $env->{REQUEST_URI}    = $path;
    $env->{PATH_INFO}      = $path;
    my $query = encode_json( $self->query(@args) );
    $env->{'psgi.input'} = IO::String->new($query);
    $env->{CONTENT_LENGTH} = length($query);
}

sub call {
    my ( $self, $env ) = @_;
    if ( $env->{REQUEST_METHOD} ne 'GET' && $env->{REQUEST_METHOD} ne 'POST' ) {
        return [ 403, [], ['Not allowed'] ];
    } elsif ( $env->{PATH_INFO} =~ /^\/_search/ ) {
        return Plack::App::Proxy->new(
                 remote => "http://" . $self->remote . "/cpan/" . $self->index )
          ->to_app->($env);
    } else {
        return $self->handle($env);
    }
}

1;

__END__

=head1 DESCRIPTION

The C<MetaCPAN::Plack> namespace consists if Plack applications. For each
endpoint exists one class which handles the request.

There are two types of apps under this namespace. 
Modules like L<MetaCPAN::Plack::Module> need to perform a search based
on the name to get the latest version of a module. To make this possible
C<PATH_INFO> needs to be rewritten and a body needs to be injected 
in the request.

Other modules like L<MetaCPAN::Plack::Author> are requested by the id,
so there is no need to issue a search. Hoewever, this module will
strip the ElasticSearch meta data and return the C<_source> attribute.

=head1 METHODS

=head2 call

Catch non-GET requests and return a 403 status if there was a non-GET request.

If the C<PATH_INFO> is a C</_search>, forward request to ElasticSearch.

Otherwise let the module handle the request (i.e. call C<< $self->handle >>).

=head2 rewrite_request

Sets the C<PATH_INFO> and a body, if necessary. Calls L</query> for a
query object.

=head2 get_first_result

Returns the C<_source> of the first result.

=head2 get_source

Get the C<_source>.

=head2 process_chunks

Handling chunked responses.

=head1 SUBCLASSES

Subclasses have to implement some of the following methods:

=head2 index

Simply return the name of the index.

=head2 handle

This method is called from L</call> and passed the C<$env>.
It's purpose is to call L</get_source> or L</get_first_result>
based on the type of lookup.

=head2 query

If L</handle> calls L</get_first_result>, this method will be called
to get a query object, which is passed to the ElasticSearch server.

=head1 SEE ALSO

L<MetaCPAN::Plack::Base>
