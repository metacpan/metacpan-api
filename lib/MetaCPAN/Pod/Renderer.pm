package MetaCPAN::Pod::Renderer;

use MetaCPAN::Moose;

use MetaCPAN::Pod::XHTML;
use MetaCPAN::Types::TypeTiny qw( Uri );
use Pod::Markdown;
use Pod::POM ();
use Pod::POM::View::Pod;
use Pod::Text ();

has perldoc_url_prefix => (
    is      => 'ro',
    isa     => Uri,
    coerce  => 1,
    default => 'https://metacpan.org/pod/',
    writer  => '_set_perldoc_url_prefix',
);

has nix_X_codes => ( is => 'ro' );

has no_errata_section => (
    is      => 'ro',
    default => 1,
);

has link_mappings => ( is => 'ro' );

sub markdown_renderer {
    my $self = shift;
    return Pod::Markdown->new(
        perldoc_url_prefix => $self->perldoc_url_prefix );
}

sub pod_renderer {
    my $self = shift;
    return Pod::POM->new;
}

sub text_renderer {
    my $self = shift;
    return Pod::Text->new( sentence => 0, width => 78 );
}

sub html_renderer {
    my $self = shift;

    my $parser = MetaCPAN::Pod::XHTML->new;

    $parser->html_footer('');
    $parser->html_header('');
    $parser->index(1);
    $parser->anchor_items(1);
    $parser->no_errata_section( $self->no_errata_section );
    $parser->perldoc_url_prefix( $self->perldoc_url_prefix );
    $parser->link_mappings( $self->link_mappings );

    return $parser;
}

sub to_markdown {
    my $self   = shift;
    my $source = shift;

    return $self->_generic_render( $self->markdown_renderer, $source );
}

sub to_text {
    my $self   = shift;
    my $source = shift;

    return $self->_generic_render( $self->text_renderer, $source );
}

sub to_html {
    my $self   = shift;
    my $source = shift;

    return $self->_generic_render( $self->html_renderer, $source );
}

sub to_pod {
    my $self   = shift;
    my $source = shift;

    my $renderer = $self->pod_renderer;
    my $pom      = $renderer->parse_text($source);
    return Pod::POM::View::Pod->print($pom);
}

sub _generic_render {
    my $self     = shift;
    my $renderer = shift;
    my $source   = shift;
    my $output   = q{};

    $renderer->output_string( \$output );
    $renderer->parse_string_document($source);

    return $output;
}

__PACKAGE__->meta->make_immutable;
1;
