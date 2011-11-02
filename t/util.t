use Test::Most;
use strict;
use warnings;
use MetaCPAN::Util;
use CPAN::Meta;

is( MetaCPAN::Util::numify_version(1),        1.000 );
is( MetaCPAN::Util::numify_version('010'),    10.000 );
is( MetaCPAN::Util::numify_version('v2.1.1'), 2.001001 );
is( MetaCPAN::Util::numify_version(undef),    0.000 );
is( MetaCPAN::Util::numify_version('LATEST'), 0.000 );
is( MetaCPAN::Util::numify_version('0.20_8'), 0.20008 );
is( MetaCPAN::Util::numify_version('0.20_108'), 0.20108 );

lives_ok { is(version("2a"), 2) };
lives_ok { is(version("V0.01"), 0.01) };
lives_ok { is(version('0.99_1'), '0.99001') };
lives_ok { is(version('0.99.01'), '0.99.01') };

is(MetaCPAN::Util::strip_pod('hello L<link|http://www.google.com> foo'), 'hello link foo');
is(MetaCPAN::Util::strip_pod('hello L<Module/section> foo'), 'hello section in Module foo');
is(MetaCPAN::Util::strip_pod('for L<Dist::Zilla>'), 'for Dist::Zilla');
is(MetaCPAN::Util::strip_pod('without a leading C<$>.'), 'without a leading $.');

sub version {
    CPAN::Meta->new(
                     { name    => 'foo',
                       license => 'unknown',
                       version => MetaCPAN::Util::fix_version(shift) } )->version;
}

done_testing;
