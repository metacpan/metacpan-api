package MetaCPAN::Pod::XHTML;

use Moose;
extends 'Pod::Simple::XHTML';

sub perldoc_url_prefix {
    'http://metacpan.org/module/'
}

1;

=pod

=head2 perldoc_url_prefix

Set perldoc domain to C<metacpan.org>.

=cut

