use strict;
use warnings;

use CPAN::Meta;
use MetaCPAN::Util qw( numify_version strip_pod );
use Test::Most;

is( numify_version(1),          1.000 );
is( numify_version('010'),      10.000 );
is( numify_version('v2.1.1'),   2.001001 );
is( numify_version(undef),      0.000 );
is( numify_version('LATEST'),   0.000 );
is( numify_version('0.20_8'),   0.208 );
is( numify_version('0.20_88'),  0.2088 );
is( numify_version('0.208_8'),  0.2088 );
is( numify_version('0.20_108'), 0.20108 );
is( numify_version('v0.9_9'),   0.099 );

lives_ok { is( version('2a'),      2 ) };
lives_ok { is( version('V0.01'),   'v0.01' ) };
lives_ok { is( version('0.99_1'),  '0.99_1' ) };
lives_ok { is( version('0.99.01'), 'v0.99.01' ) };

is( strip_pod('hello L<link|http://www.google.com> foo'), 'hello link foo' );
is( strip_pod('hello L<Module/section> foo'), 'hello section in Module foo' );
is( strip_pod('for L<Dist::Zilla>'),          'for Dist::Zilla' );
is( strip_pod('without a leading C<$>.'),     'without a leading $.' );

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
