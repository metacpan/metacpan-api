use strict;
use warnings;

package    # no_index
    MetaCPAN::TestHelpers;

use FindBin;
use Git::Helpers qw( checkout_root );
use JSON;
use MetaCPAN::Script::Runner;
use MetaCPAN::TestServer;
use Path::Class qw( dir );
use Try::Tiny;
use Test::More;
use Test::Routine::Util;

use base 'Exporter';
our @EXPORT = qw(
    catch
    get_config
    decode_json_ok
    encode_json
    finally
    hex_escape
    multiline_diag
    run_tests
    test_distribution
    test_release
    try
);

=head1 EXPORTS

=head2 multiline_diag

    multiline_diag(file1 => $mutliple_lines, file2 => $long_text);

Prints out multiline text blobs in an way that's (hopefully) easier to read.
Passes strings through L</hex_escape>.

=cut

sub multiline_diag {
    while ( my ( $name, $str ) = splice( @_, 0, 2 ) ) {
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

sub decode_json_ok {
    my ($json) = @_;
    $json = $json->content
        if try { $json->isa('HTTP::Response') };
    ok( my $obj = try { decode_json($json) }, 'valid json' );
    return $obj;
}

sub test_distribution {
    my ( $name, $args, $desc ) = @_;
    run_tests(
        $desc || "Distribution data for $name",
        ['MetaCPAN::Tests::Distribution'],
        { name => $name, %$args }
    );
}

sub test_release {
    my $release = {};

    # If the first arg is a string, treat it like 'AUTHOR/Release-Name'.
    if ( !ref( $_[0] ) ) {
        my ( $author, $name ) = split /\//, shift;
        $release = { name => $name, author => $author };
    }

    my ( $args, $desc ) = @_;
    $args = { %$release, %$args };
    run_tests( $desc || "Release data for $args->{author}/$args->{name}",
        ['MetaCPAN::Tests::Release'], $args, );
}

sub get_config {
    my $config = do {

        # build_config expects test to be t/*.t
        local $FindBin::RealBin = dir( undef, checkout_root(), 't' );
        MetaCPAN::Script::Runner->build_config;
    };
    return $config;
}

1;
