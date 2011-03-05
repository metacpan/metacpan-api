package MetaCPAN::Plack::Pod;

use base 'MetaCPAN::Plack::Module';

use strict;
use warnings;
use MetaCPAN::Pod::XHTML;

__PACKAGE__->mk_accessors(qw(cpan));

sub handle {
    my ( $self, $env ) = @_;
    if ( $env->{REQUEST_URI} =~ m{\A/pod/([^\/]*?)\/?$} ) {
        $self->rewrite_request($env);
        my $res =
          Plack::App::Proxy->new( remote => "http://127.0.0.1:9200/cpan" )
          ->to_app->($env);
        return sub {
            my $respond = shift;
            $res->(
                sub {
                    my $res = shift;
                    Plack::Util::header_remove( $res->[1], 'Content-Length' );
                    my $writer = $respond->($res);
                    my $json   = "";
                    return Plack::Util::inline_object(
                        write => sub { $json .= $_[0] },
                        close => sub {
                            $json = JSON::XS::decode_json($json);
                            my $hit;
                            unless ( $hit =
                                     shift( @{ $json->{hits}->{hits} } ) )
                            {
                                $writer->write("not found");
                                $writer->close;
                                return;
                            }
                            my $file    = $hit->{_source}->{file};
                            my $release = $hit->{_source}->{release};
                            my $author  = $hit->{_source}->{author};
                            $env->{REQUEST_URI} = $env->{PATH_INFO} =
                              "/source/$author/$release/$file";
                            delete $env->{CONTENT_LENGTH};
                            delete $env->{'psgi.input'};

                            my $res = MetaCPAN::Plack::Source->new(
                                      { cpan => $self->cpan } )->to_app->($env);
                            if ( ref $res->[2] eq 'ARRAY' ) {
                                $writer->write( $res->[2]->[0] );
                                $writer->close;
                                return;
                            }

                            my $source = "";
                            my $body   = $res->[2];
                            while ( my $line = $body->getline ) {
                                $source .= $line;
                            }

                            $writer->write( $self->build_pod_html($source) );
                            $writer->close;
                        } );
                } );
        };
    } else {
        $env->{REQUEST_URI} =~ s/^\/pod\//\/source\//;
        $env->{PATH_INFO} = $env->{REQUEST_URI};

        my $res =
          MetaCPAN::Plack::Source->new( { cpan => $self->cpan } )
          ->to_app->($env);
        if ( ref $res->[2] eq 'ARRAY' ) {
            die;
            return $res;
        }

        my $source = "";
        my $body   = $res->[2];
        while ( my $line = $body->getline ) {
            $source .= $line;
        }
        return [200, ['Content-type', 'text/html'], [$self->build_pod_html($source)]];
    }
}

sub build_pod_html {
    my ( $self, $content ) = @_;
    my $parser = MetaCPAN::Pod::XHTML->new();
    $parser->index(1);
    $parser->html_header('');
    $parser->html_footer('');
    $parser->perldoc_url_prefix('');
    $parser->no_errata_section(1);
    my $html = "";
    $parser->output_string( \$html );
    $parser->parse_string_document($content);
    return $html;
}

1;
__END__

=head1 METHODS

=head2 index

Returns C<file>, because ther eis no C<pod> index, so we look
the module up in the C<file> index.

=head2 query

Builds a query that looks for the name of the module,
sorts by date descending and fetches only to first 
result.

=head2 handle

Get the first result from the response and return it.

=head1 SEE ALSO

L<MetaCPAN::Plack::Base>
