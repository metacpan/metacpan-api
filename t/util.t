use Test::Most;
use strict;
use warnings;
use utf8;       # This file contains literal UTF8 strings
use MetaCPAN::Util;
use CPAN::Meta;
use Pod::Text;

is( MetaCPAN::Util::numify_version(1),        1.000 );
is( MetaCPAN::Util::numify_version('010'),    10.000 );
is( MetaCPAN::Util::numify_version('v2.1.1'), 2.001001 );
is( MetaCPAN::Util::numify_version(undef),    0.000 );
is( MetaCPAN::Util::numify_version('LATEST'), 0.000 );
is( MetaCPAN::Util::numify_version('0.20_8'), 0.208 );
is( MetaCPAN::Util::numify_version('0.20_88'), 0.200088 );
is( MetaCPAN::Util::numify_version('0.208_8'), 0.208008 );
is( MetaCPAN::Util::numify_version('0.20_108'), 0.2000108 );

lives_ok { is(version("2a"), 2) };
lives_ok { is(version("V0.01"), 0.01) };
lives_ok { is(version('0.99_1'), '0.99001') };
lives_ok { is(version('0.99.01'), '0.99.01') };

is(
    MetaCPAN::Util::strip_pod('hello L<link|http://www.google.com> foo'),
    'hello link <http://www.google.com> foo',
    'link to URL'
);
is(
    MetaCPAN::Util::strip_pod('hello L<Module/section> foo'),
    'hello "section" in Module foo',
    'link to Module/section'
);
is(
    MetaCPAN::Util::strip_pod('for L<Dist::Zilla>'),
    'for Dist::Zilla',
    'link to Module'
);
is(
    MetaCPAN::Util::strip_pod('without a leading C<$>.'),
    'without a leading $.',
    'code section'
);
is(
    MetaCPAN::Util::strip_pod('B<bold> I<italics> C<code> F<file>'),
    'bold italics code file',
    'character formatting stripped'
);
is(
    MetaCPAN::Util::strip_pod('E<lt>me@example.comE<gt>'),
    '<me@example.com>',
    'POD escapes decoded'
);
is(
    MetaCPAN::Util::strip_pod("Para one.\n\nPara\ntwo.\n\nPara     three.\n"),
    "Para one.\nPara two.\nPara three.",
    'whitespace collapsed, paras as lines'
);
is(
    MetaCPAN::Util::strip_pod("Para one.\n\n  verbatim a\n  verbatim     b\nPara     two.\n"),
    "Para one.\nverbatim a\nverbatim b\nPara two.",
    'verbatim lines not wrapped'
);
is(
    MetaCPAN::Util::strip_pod("=encoding utf8\n\nMoose - \xC3\x89lan\n"),
    "Moose - Élan",
    'utf8 bytes decoded'
);
is(
    MetaCPAN::Util::strip_pod("Moose - \xC3\x89lan\n"),
    "Moose - Élan",
    'utf8 bytes decoded - even without encoding declaration'
);
is(
    MetaCPAN::Util::strip_pod("=encoding iso8859-1\n\nMoose - \xC9lan\n"),
    "Moose - Élan",
    'Latin1 bytes decoded'
);
is(
    MetaCPAN::Util::strip_pod("Moose - \xC9lan\n"),
    "Moose - Élan",
    'Latin1 bytes decoded - even without encoding declaration'
);
is(
    MetaCPAN::Util::strip_pod(
        "=encoding CP1252\n\nMoose \x96\x97 \x91\xC9lan\x92 \x93Dou\xE9\x94"
    ),
    "Moose –— ‘Élan’ “Doué”",
    'CP1252 bytes decoded'
);
is(
    MetaCPAN::Util::strip_pod("Moose \x96\x97 \x91\xC9lan\x92 \x93Dou\xE9\x94"),
    "Moose -- 'Élan' \"Doué\"",
    'CP1252 bytes de-smarted without encoding declaration'
);
is(
    MetaCPAN::Util::strip_pod(
        "=encoding iso8859-2\n\nAlien::Not - \xD2\xF4\xFE \xE3\xF1 \xB1\xE5\xED\xEA\xF2"
    ),
    "Alien::Not - Ňôţ ăń ąĺíęň",
    'strip_pod honoured latin2 encoding'
);

sub version {
    CPAN::Meta->new({
        name    => 'foo',
        license => 'unknown',
        version => MetaCPAN::Util::fix_version(shift)
    })->version;
}

# extract_section tests

{
    my $content = <<EOF;
=head1 NAME

Some::Thing - Test

=head1 NAMED PIPE

Some data about a named pipe

EOF

    my $section = MetaCPAN::Util::extract_section( $content, 'NAME');
    is($section, 'Some::Thing - Test', 'NAME matched correct head1 section');
}

# https://github.com/CPAN-API/cpan-api/issues/167
{
    my $content = <<EOF;
=head1 NAMED PIPE

Some description

=cut
EOF

    my $section = MetaCPAN::Util::extract_section( $content, 'NAME');
    is($section, undef, 'NAMED did not match requested section NAME');
}

# section extraction should honour =encoding declaration

sub pod_to_text {
    my($pod) = @_;

    my $parser = Pod::Text->new;
    my $text   = "";
    $parser->output_string( \$text );
    $parser->parse_string_document("=pod\n\n$pod");
    return $text;
}

{
    my $content = <<"EOF";

=encoding CP1252

=head1 NAME

Some::Thing - Somethin\x92 or nothin\x92

=head1 DESCRIPTION

This is meant to be \x93descriptive\x94.

EOF

    my $section = MetaCPAN::Util::extract_section( $content, 'NAME');
    is(
        $section,
        "=encoding CP1252\n\nSome::Thing - Somethin\x92 or nothin\x92",
        'NAME section came through as bytes with =encoding declaration'
    );
    my $formatted = pod_to_text( $section );
    like(
        $formatted,
        qr/Some::Thing - Somethin’ or nothin’/,
        'POD parser was able to decode bytes'
    );

    $section = MetaCPAN::Util::extract_section( $content, 'DESCRIPTION');
    is(
        $section,
        "=encoding CP1252\n\nThis is meant to be \x93descriptive\x94.",
        'DESCRIPTION section came through as bytes with =encoding declaration'
    );
    $formatted = pod_to_text( $section );
    like(
        $formatted,
        qr/This is meant to be “descriptive”./,
        'POD parser was able to decode bytes'
    );

}

done_testing;
