use strict;
use warnings;

use CPAN::Meta;
use MetaCPAN::Util qw( numify_version strip_pod );
use Test::Most;

{
    my %versions = (
        '010'     => 10,
        '0.20_8'  => 0.208,
        '0.208_8' => 0.2088,
        '0.20_88' => 0.2088,
        1         => 1,
        LATEST    => 0,
        undef     => 0,
        'v0.9_9'  => 0.099,
        'v2.1.1'  => 2.001001,
        'v2.0.0'  => 2.0,
    );

    foreach my $before ( sort keys %versions ) {
        is( numify_version($before), $versions{$before},
            "$before => $versions{$before}" );
    }
}

{
    my %versions = (
        '2a'      => 2,
        'V0.01'   => 'v0.01',
        '0.99_1'  => '0.99_1',
        '0.99.01' => 'v0.99.01',
        'v1.2'    => 'v1.2',
    );
    foreach my $before ( sort keys %versions ) {
        lives_ok {
            is( version($before), $versions{$before},
                "$before => $versions{$before}" )
        }
        "$before => $versions{$before} does not die";
    }
}

is(
    strip_pod('hello L<link|http://www.google.com> foo'),
    'hello link foo',
    'strip_pod strips http links'
);
is(
    strip_pod('hello L<Module/section> foo'),
    'hello section in Module foo',
    'strip_pod strips internal links'
);
is(
    strip_pod('for L<Dist::Zilla>'),
    'for Dist::Zilla',
    'strip_pod strips module links'
);
is(
    strip_pod('without a leading C<$>.'),
    'without a leading $.',
    'strip_pod strips C<>'
);

sub version {
    CPAN::Meta->new(
        {
            name    => 'foo',
            license => 'unknown',
            version => MetaCPAN::Util::fix_version(shift)
        }
    )->version;
}

# extract_section tests

{
    my $content = <<EOF;
=head1 NAME

Some::Thing - Test

=head1 NAMED PIPE

Some data about a named pipe

EOF

    my $section = MetaCPAN::Util::extract_section( $content, 'NAME' );
    is( $section, 'Some::Thing - Test',
        'NAME matched correct head1 section' );
}

# https://github.com/CPAN-API/cpan-api/issues/167
{
    my $content = <<EOF;
=head1 NAMED PIPE

Some description

=cut
EOF

    my $section = MetaCPAN::Util::extract_section( $content, 'NAME' );
    is( $section, undef, 'NAMED did not match requested section NAME' );
}

done_testing;
