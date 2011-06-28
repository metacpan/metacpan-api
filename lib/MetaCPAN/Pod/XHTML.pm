package MetaCPAN::Pod::XHTML;

use Moose;
extends 'Pod::Simple::XHTML';

sub perldoc_url_prefix {
    'http://beta.metacpan.org/module/'
}

sub end_item_text   {
    # idify =item content, reset 'scratch'
    my $id = $_[0]->idify($_[0]{'scratch'});
    my $text = $_[0]{scratch};
    $_[0]{'scratch'} = '';

    # construct whole element here because we need the
    # contents of the =item to idify it
    if ($_[0]{'in_dd'}[ $_[0]{'dl_level'} ]) {
        $_[0]{'scratch'} = "</dd>\n";
        $_[0]{'in_dd'}[ $_[0]{'dl_level'} ] = 0;
    }

    $_[0]{'scratch'} .= qq{<dt id="$id">$text</dt>\n<dd>};
    $_[0]{'in_dd'}[ $_[0]{'dl_level'} ] = 1;
    $_[0]->emit;
}

1;

=pod

=head2 perldoc_url_prefix

Set perldoc domain to C<metacpan.org>.

=cut

