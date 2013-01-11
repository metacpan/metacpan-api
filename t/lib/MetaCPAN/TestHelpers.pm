package # no_index
    MetaCPAN::TestHelpers;

use base 'Exporter';
our @EXPORT = qw(
    multiline_diag hex_escape
);
use Test::More;

=head1 EXPORTS

=head2 multiline_diag

    multiline_diag(file1 => $mutliple_lines, file2 => $long_text);

Prints out multiline text blobs in an way that's (hopefully) easier to read.
Passes strings through L</hex_escape>.

=cut

sub multiline_diag {
    while( my ($name, $str) = splice(@_, 0, 2) ){
        $str =~ s/^/ |/mg;
        diag "$name:\n" . hex_escape($str) . "\n";
    }
}

=head2 hex_escape

Replaces many uncommon bytes with the equivalent \x{deadbeef} escape.

=cut

sub hex_escape {
    my $s = shift;
    $s =~ s/([^a-zA-Z0-9[:punct:] \t\n])/sprintf("\\x{%x}", ord $1)/ge;
    $s;
}

1;
