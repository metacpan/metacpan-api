package MetaCPAN::Server::View::Pod;

use strict;
use warnings;

use MetaCPAN::Pod::Renderer;
use Moose;

extends 'Catalyst::View';

sub process {
    my ( $self, $c ) = @_;

    my $renderer = MetaCPAN::Pod::Renderer->new;

    my $content = $c->res->body || $c->stash->{source};
    $content = eval { join( q{}, $content->getlines ) };

    my ( $body, $content_type );
    my $accept = eval { $c->req->preferred_content_type } || 'text/html';
    my $show_errors = $c->req->params->{show_errors};

    my $x_codes = $c->req->params->{x_codes};
    $x_codes = $c->config->{pod_html_x_codes} unless defined $x_codes;

    if ( $accept eq 'text/plain' ) {
        $body         = $self->_factory->to_txt($content);
        $content_type = 'text/plain';
    }
    elsif ( $accept eq 'text/x-pod' ) {
        $body         = $self->_factory->to_pod($content);
        $content_type = 'text/plain';
    }
    elsif ( $accept eq 'text/x-markdown' ) {
        $body         = $self->_factory->to_markdown($content);
        $content_type = 'text/plain';
    }
    else {
        $body = $self->build_pod_html( $content, $show_errors, $x_codes );
        $content_type = 'text/html';
    }

    $c->res->content_type($content_type);
    $c->res->body($body);
}

sub build_pod_html {
    my ( $self, $source, $show_errors, $x_codes ) = @_;

    my $renderer = $self->_factory->html_renderer;
    $renderer->nix_X_codes( !$x_codes );
    $renderer->no_errata_section( !$show_errors );

    my $html = q{};
    $renderer->output_string( \$html );
    $renderer->parse_string_document($source);
    return $html;
}

sub _factory {
    my $self = shift;
    return MetaCPAN::Pod::Renderer->new;
}

1;
