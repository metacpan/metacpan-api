use strict;
use warnings;
use lib 't/lib';

use CPAN::Meta     ();
use MetaCPAN::Util qw(
    extract_section
    generate_sid
    numify_version
    paginate
    strip_pod
);

use Test::Fatal qw( exception );
use Test::More;

ok( generate_sid(), 'generate_sid' );

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
        is exception {
            is( version($before), $versions{$before},
                "$before => $versions{$before}" )
        }, undef, "$before => $versions{$before} does not die";
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
    CPAN::Meta->new( {
        name    => 'foo',
        license => 'unknown',
        version => MetaCPAN::Util::fix_version(shift)
    } )->version;
}

# extract_section tests

{
    my $content = <<EOF;
=head1 NAME

Some::Thing - Test

=head1 NAMED PIPE

Some data about a named pipe

EOF

    my $section = extract_section( $content, 'NAME' );
    is( $section, 'Some::Thing - Test',
        'NAME matched correct head1 section' );
}

# https://github.com/metacpan/metacpan-api/issues/167
{
    my $content = <<EOF;
=head1 NAMED PIPE

Some description

=cut
EOF

    my $section = extract_section( $content, 'NAME' );
    is( $section, undef, 'NAMED did not match requested section NAME' );
}

subtest 'paginate' => sub {
    is_deeply( [ paginate( 1, 10 ) ], [ 1, 10, 0 ], 'page 1 size 10 from 0' );
    is_deeply(
        [ paginate( 2, 50 ) ],
        [ 2, 50, 50 ],
        'page 2 size 50 from 50'
    );

    is_deeply( [ paginate( undef, 10 ) ], [ 1, 10, 0 ],
        'page defaults to 1' );
    is_deeply(
        [ paginate( 1, undef ) ],
        [ 1, 250, 0 ],
        'size defaults to 250'
    );

    is_deeply( [ paginate( -5, 10 ) ], [ 1, 10, 0 ], 'negative page => 1' );
    is_deeply( [ paginate( 1, -3 ) ], [ 1, 250, 0 ], 'negative size => 250' );
    is_deeply( [ paginate( 0, 10 ) ], [ 1, 10,  0 ], 'zero page => 1' );
    is_deeply( [ paginate( 1, 0 ) ],  [ 1, 250, 0 ], 'zero size => 250' );

    # page*size == from+size; ES allows from+size <= max_result_window,
    # so page*size == 1000 is the last valid request.
    is_deeply(
        [ paginate( 4, 250 ) ],
        [ 4, 250, 750 ],
        'page*size == 1000 is allowed'
    );
    is_deeply(
        [ paginate( 10, 100 ) ],
        [ 10, 100, 900 ],
        'page*size == 1000 with different values'
    );

    is_deeply( [ paginate( 5, 250 ) ], [], 'page*size > 1000 returns empty' );
    is_deeply( [ paginate( 100, 250 ) ],
        [], 'way beyond window returns empty' );

    is_deeply( [ paginate( 1, 250 ) ], [ 1, 250, 0 ], 'max size accepted' );
    is_deeply(
        [ paginate( 1000, 1 ) ],
        [ 1000, 1, 999 ],
        'max page accepted'
    );
    is_deeply( [ paginate( 1001, 1 ) ], [], 'page beyond window' );

    # Custom max_result_window parameter.
    is_deeply(
        [ paginate( 20, 250, 5000 ) ],
        [ 20, 250, 4750 ],
        'custom window: page*size == 5000 is allowed'
    );
    is_deeply( [ paginate( 21, 250, 5000 ) ],
        [], 'custom window: page*size > 5000 returns empty' );
    is_deeply( [ paginate( 1, 500 ) ],  [ 1, 250, 0 ], 'size > 250 capped' );
    is_deeply( [ paginate( 1, 1000 ) ], [ 1, 250, 0 ], 'size = 1000 capped' );

    is_deeply( [ paginate( 1.9, 10.7 ) ], [ 1, 250, 0 ], 'float page => 1' );
    is_deeply( [ paginate( 2.5, 50 ) ],   [ 1, 50,  0 ], 'float page => 1' );
    is_deeply( [ paginate( 1, 10.5 ) ], [ 1, 250, 0 ], 'float size => 250' );

    is_deeply(
        [ paginate( "abc", 10 ) ],
        [ 1, 10, 0 ],
        'non-numeric page => 1'
    );
    is_deeply(
        [ paginate( 1, "xyz" ) ],
        [ 1, 250, 0 ],
        'non-numeric size => 250'
    );
    is_deeply(
        [ paginate( "3abc", 10 ) ],
        [ 1, 10, 0 ],
        'partial numeric page => 1'
    );
};

done_testing;
