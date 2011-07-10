package MetaCPAN::Server::View::Pod;

use Moose;
extends 'Catalyst::View';

use MetaCPAN::Pod::XHTML;
use Pod::POM;
use Pod::Text;
use Pod::Markdown;
use IO::String;

sub process {
    my ($self, $c) = @_;
    my $content = $c->res->body || $c->stash->{source};
    $content = eval { join($/, $content->getlines) };
    my ($body, $content_type);
    my $accept = $c->req->preferred_content_type || 'text/html';
    if($accept eq 'text/plain') {
      $body = $self->build_pod_txt( $content );
      $content_type = 'text/plain';
    } elsif($accept eq 'text/x-pod') {
      $body = $self->extract_pod( $content );
      $content_type = 'text/plain';
    } elsif($accept eq 'text/x-markdown') {
      $body = $self->build_pod_markdown( $content );
      $content_type = 'text/plain';
    } else {
      $body = $self->build_pod_html( $content );
      $content_type = 'text/html';
    }
    $c->res->content_type($content_type);
    $c->res->body($body);
}

sub build_pod_markdown {
    my $self = shift;
    my $parser = Pod::Markdown->new;
    $parser->parse_from_filehandle(IO::String->new(shift));
    return $parser->as_markdown;
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