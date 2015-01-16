package MetaCPAN::Server::View::Pod;

use strict;
use warnings;

use MetaCPAN::Pod::XHTML;
use Moose;
use Pod::Markdown;
use Pod::POM;
use Pod::Text;

extends 'Catalyst::View';

sub process {
    my ( $self, $c ) = @_;
    my $content = $c->res->body || $c->stash->{source};
    $content = eval { join( "", $content->getlines ) };
    my ( $body, $content_type );
    my $accept = eval { $c->req->preferred_content_type } || 'text/html';
    my $show_errors = $c->req->params->{show_errors};

    # This could default to a config var (feature flag).
    my $x_codes = $c->req->params->{x_codes};

    if ( $accept eq 'text/plain' ) {
        $body         = $self->build_pod_txt($content);
        $content_type = 'text/plain';
    }
    elsif ( $accept eq 'text/x-pod' ) {
        $body         = $self->extract_pod($content);
        $content_type = 'text/plain';
    }
    elsif ( $accept eq 'text/x-markdown' ) {
        $body         = $self->build_pod_markdown($content);
        $content_type = 'text/plain';
    }
    else {
        $body = $self->build_pod_html( $content, $show_errors, $x_codes );
        $content_type = 'text/html';
    }
    $c->res->content_type($content_type);
    $c->res->body($body);
}

sub build_pod_markdown {
    my ( $self, $source ) = @_;
    my $parser = Pod::Markdown->new;
    my $mkdn   = q[];
    $parser->output_string( \$mkdn );
    $parser->parse_string_document($source);
    return $mkdn;
}

sub build_pod_html {
    my ( $self, $source, $show_errors, $x_codes ) = @_;
    my $parser = MetaCPAN::Pod::XHTML->new();
    $parser->index(1);
    $parser->html_header('');
    $parser->html_footer('');
    $parser->perldoc_url_prefix('');
    $parser->no_errata_section( !$show_errors );
    $parser->nix_X_codes( !$x_codes );
    my $html = "";
    $parser->output_string( \$html );
    $parser->parse_string_document($source);
    return $html;
}

sub extract_pod {
    my ( $self, $source ) = @_;
    my $parser = Pod::POM->new;
    my $pom    = $parser->parse_text($source);
    return Pod::POM::View::Pod->print($pom);
}

sub build_pod_txt {
    my ( $self, $source ) = @_;
    my $parser = Pod::Text->new( sentence => 0, width => 78 );
    my $text = "";
    $parser->output_string( \$text );
    $parser->parse_string_document($source);
    return $text;
}

1;
