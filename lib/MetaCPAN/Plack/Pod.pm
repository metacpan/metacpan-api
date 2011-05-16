package MetaCPAN::Plack::Pod;

use base 'MetaCPAN::Plack::Module';

use strict;
use warnings;
use MetaCPAN::Pod::XHTML;
use Try::Tiny;

sub handle {
    my ( $self, $env ) = @_;
    my $source;
    if ( $env->{REQUEST_URI} =~ m{\A/pod/([^\/]*?)\/?$} ) {
        $env->{REQUEST_URI} = "/module/$1";;
        $env->{PATH_INFO} = "/$1";
        $env->{SCRIPT_NAME} = "/module";
        my $res = MetaCPAN::Plack::Module->new({
            index => $self->index
        })->to_app->($env);
        return $res if($res->[0] != 200);
        my $hit = JSON::XS::decode_json(join("", @{$res->[2]}));

        my $file    = $hit->{path};
        my $release = $hit->{release};
        my $author  = $hit->{author};
        $env->{REQUEST_URI} = $env->{PATH_INFO} =
          "/source/$author/$release/$file";
        delete $env->{CONTENT_LENGTH};
        delete $env->{'psgi.input'};
        $source = MetaCPAN::Plack::Source->new(
                  { cpan => $self->cpan } )->to_app->($env)->[2];
    } else {
        $env->{REQUEST_URI} =~ s/^\/pod\//\/source\//;
        $env->{PATH_INFO} = $env->{REQUEST_URI};

        $source =
          MetaCPAN::Plack::Source->new( { cpan => $self->cpan } )
          ->to_app->($env)->[2];
    }
    
    return [200, ['Content-type', 'text/html', $self->_headers], [$self->build_pod_html($source)]];
}

sub build_pod_html {
    my ( $self, $body ) = @_;
    my $source = "";
    while ( my $line = $body->getline ) {
        $source .= $line;
    }
    my $parser = MetaCPAN::Pod::XHTML->new();
    $parser->index(1);
    $parser->html_header('');
    $parser->html_footer('');
    $parser->perldoc_url_prefix('');
    $parser->no_errata_section(1);
    my $html = "";
    $parser->output_string( \$html );
    $parser->parse_string_document($source);
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
