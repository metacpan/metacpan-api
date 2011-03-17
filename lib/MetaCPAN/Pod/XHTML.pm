package MetaCPAN::Pod::XHTML;

use Moose;
extends 'Pod::Simple::XHTML';

sub start_L {
    my ( $self, $flags ) = @_;
    my ( $type, $to, $section ) = @{$flags}{ 'type', 'to', 'section' };

    my $url
        = $type eq 'url' ? $to
        : $type eq 'pod' ? $self->resolve_pod_page_link( $to, $section )
        : $type eq 'man' ? $self->resolve_man_page_link( $to, $section )
        :                  undef;
    $url ||= '';
    my $pound = '#';
    my $class
        = ( $type eq 'pod' && ($url !~ m{$pound}) ) ? ' class="moduleLink"' : '';

    $self->{'scratch'} .= qq[<a href="$url"$class>];
}

sub start_Verbatim {

}

sub end_Verbatim {

    $_[0]{'scratch'} = '<pre>' . $_[0]{'scratch'} . '</pre>';
    $_[0]->emit;

}

1;

=pod

=head2 start_L

Add the "moduleLink" class to any hrefs which link directly to module docs.

=head2 start_Verbatim

Override default behaviour by doing nothing.

=head2 end_Verbatim

Wrap code snippets in <pre> tags for easier syntax highlighting.

=cut

