package MetaCPAN::Plack::Base;
use base 'Plack::Component';
use strict;
use warnings;
use JSON::XS;
use Try::Tiny;
use IO::String;
use Plack::App::Proxy;
use MetaCPAN::Plack::Request;
use mro 'c3';
use Try::Tiny;

__PACKAGE__->mk_accessors(qw(cpan remote model index));

sub get_source {
    my ( $self, $req ) = @_;
    my ( undef, undef, @args ) = split( "/", $req->path );
    try {
        my $res =
          $self->index->type( $self->type )->inflate(0)->get( $args[0] );
        return [ 200, [ $self->_headers ], [ encode_json( $res->{_source} ) ] ];
    }
    catch {
        return $self->error404;
    };
}


sub error404 {
    [ 404, [shift->_headers], ['{"message":"Not found"}'] ];
}

sub get_first_result {
    my ( $self, $req ) = @_;
    my ( undef, undef, @args ) = split( "/", $req->path );
    my $query = $self->query(@args);
    $query->{size} = 1;
    try {
        my ($res) =
          $self->index->type( $self->type )->query($query)->inflate(0)->all;
        if ( $res->{hits}->{total} ) {
            return [ 200,
                     [ $self->_headers ],
                     [ encode_json( $res->{hits}->{hits}->[0]->{_source} ) ] ];
        } else {
            return $self->error404;
        }
    }
    catch {
        return $self->error404;
    };
}


sub call {
    my ( $self, $env ) = @_;
    my $req = MetaCPAN::Plack::Request->new($env);
    if ( $req->method eq "OPTIONS" ) {
        return [ 200, [ $self->_headers ], [] ];
    } elsif (
        !grep {
            $req->method eq $_
        } qw(GET POST) )
    {
        return [
            403,
            [ $self->_headers ],
            [ encode_json( { message => 'Not allowed' } ) ] ];
    } elsif ( $env->{PATH_INFO} =~ /^\/_search$/ ) {
      return try {
        my $body      = $req->decoded_body;
        my $transport = $self->model->es->transport;
        my $res       = $transport->request(
            {   method => $req->method,
                qs     => $req->parameters->as_hashref,
                cmd    => join( '/', '', $self->index->name, $self->type, '_search' ),
                data   => $body
            } );
        return [ 200, [ $self->_headers ], [ encode_json($res) ] ];
      } catch {
        ref $_ eq 'ARRAY'
          ? $_
          : [500, [$self->_headers], [encode_json({ message => "$_" })]];
      };
    } else {
        return $self->handle($req);
    }
}



sub _headers {
    return ( 'Access-Control-Allow-Origin',
             'http://localhost:3030',
             'Access-Control-Allow-Headers',
             'X-Requested-With, Content-Type',
             'Access-Control-Allow-Methods',
             'POST',
             'Access-Control-Max-Age',
             '17000000',
             'Access-Control-Allow-Credentials',
             'true', 'Content-type', 'application/json' );
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
