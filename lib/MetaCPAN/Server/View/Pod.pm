package MetaCPAN::Server::View::Pod;

use strict;
use warnings;

use MetaCPAN::Pod::Renderer;
use Moose;

extends 'Catalyst::View';

sub process {
    my ( $self, $c ) = @_;

    my $content = $c->res->has_body ? $c->res->body : $c->stash->{source};
    my $link_mappings = $c->stash->{link_mappings};
    my $url_prefix    = $c->stash->{url_prefix};
    if ( ref $content ) {
        $content = do { local $/; <$content> };
    }

    my ( $body, $content_type );
    my $accept      = eval { $c->req->preferred_content_type } || 'text/html';
    my $show_errors = $c->stash->{show_errors};

    my $renderer = $self->_factory(
        ( $url_prefix ? ( perldoc_url_prefix => $url_prefix ) : () ),
        no_errata_section => !$show_errors,
        ( $link_mappings ? ( link_mappings => $link_mappings ) : () ),
    );
    if ( $accept eq 'text/plain' ) {
        $body         = $renderer->to_text($content);
        $content_type = 'text/plain';
    }
    elsif ( $accept eq 'text/x-pod' ) {
        $body         = $renderer->to_pod($content);
        $content_type = 'text/plain';
    }
    elsif ( $accept eq 'text/x-markdown' ) {
        $body         = $renderer->to_markdown($content);
        $content_type = 'text/plain';
    }
    else {
        $body         = $renderer->to_html($content);
        $content_type = 'text/html';
    }

    $c->res->content_type($content_type);
    $c->res->body($body);
}

sub _factory {
    my $self = shift;
    return MetaCPAN::Pod::Renderer->new(@_);
}

1;
