package MetaCPAN::Plack::Pod;

use base 'MetaCPAN::Plack::Module';

use strict;
use warnings;
use MetaCPAN::Pod::XHTML;
use Pod::POM;
use Pod::Text;
use Try::Tiny;

sub handle {
    my ( $self, $env ) = @_;
    my $source;
    my $format;
    
    my $formats = qr{(pod|htmlpod|textpod)};
    if ( $env->{REQUEST_URI} =~ m{\A/$formats/} ) {
        $format = $1;
    }
        
    if ( $env->{REQUEST_URI} =~ m{\A/$formats/([^\/]*?)\/?$} ) {
        my $format = $1;
        my $path = $2;
        $env->{REQUEST_URI} = "/module/$2";;
        $env->{PATH_INFO} = "/$2";
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
        my $format = $env->{REQUEST_URI} =~ s/^\/$formats\//\/source\//;
        $env->{PATH_INFO} = $env->{REQUEST_URI};

        $source =
          MetaCPAN::Plack::Source->new( { cpan => $self->cpan } )
          ->to_app->($env)->[2];
    }
    
    my $content = "";
    while ( my $line = $source->getline ) {
        $content .= $line;
    }
    
    if ( $format eq 'htmlpod' ) {
        return [
           200,
           [ 'Content-type', 'text/html', $self->_headers ],
           [ $self->build_pod_html( $content ) ]
       ];       
    }
    
    if ( $format eq 'pod' ) {
        return [
           200,
           [ 'Content-type', 'text/plain', $self->_headers ],
           [ $self->extract_pod( $content ) ]
       ];       
    }    

    if ( $format eq 'textpod' ) {
        return [
           200,
           [ 'Content-type', 'text/plain', $self->_headers ],
           [ $self->build_pod_txt( $content ) ]
       ];       
    }
    
}

sub build_pod_html {
    my ( $self, $source ) = @_;

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

sub extract_pod {
    
    my ( $self, $source ) = @_;
    my $parser = Pod::POM->new;
    my $pom = $parser->parse_text( $source );
    return Pod::POM::View::Pod->print( $pom );  
    
}

sub build_pod_txt {
    
    my ( $self, $source ) = @_;

    my $parser = Pod::Text->new( sentence => 0, width => 78 );

    my $text = "";
    $parser->output_string( \$text );
    $parser->parse_string_document( $source );

    return $text;

}    

1;
__END__

=head1 METHODS

=head2 index

Returns C<file>, because there is no C<pod> index, so we look
the module up in the C<file> index.

=head2 query

Builds a query that looks for the name of the module,
sorts by date descending and fetches only to first 
result.

=head2 handle

Get the first result from the response and return it.

=head1 SEE ALSO

L<MetaCPAN::Plack::Base>
