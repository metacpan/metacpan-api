use strict;
use warnings;
use Test::More;

use MetaCPAN::Document::Module;

subtest hide_from_pause => sub {
    foreach my $test (

        # The original:
        [ 'No::CommentNL' => "package # hide\n  No::CommentNL;" ],

        # I'm not sure how PAUSE handles this one but currently we ignore it.
        [ 'No::JustNL' => "package       \n  No::JustNL;" ],

        # The good ones:
        [ 'Pkg'        => 'package Pkg;' ],
        [ 'Pkg::Ver'   => 'package Pkg::Ver v1.2.3;' ],
        [ 'Pkg::Block' => 'package Pkg::Block           { our $var = 1 }' ],
        [   'Pkg::VerBlock' => 'package Pkg::VerBlock  1.203 { our $var = 1 }'
        ],
        [ 'Pkg::SemiColons' => '; package Pkg::SemiColons; $var' ],
        [ 'Pkg::InABlock'   => '{ package Pkg::InABlock; $var }' ],

        [ 'No::JustVar' => qq["\n\$package No::JustVar;\n"] ],

        # This shouldn't match, but there's only so much we can do...
        # we're not going to eval the whole file to figure it out.
        [ 'Pkg::InsideStr' => qq["\n  package Pkg::InsideStr;\n"] ],

        [ 'No::Comment'    => qq[# package No::Comment;\n] ],
        [ 'No::Different'  => qq[package No::Different::Pkg;] ],
        [ 'No::PkgWithNum' => qq["\npackage No::PkgWithNumv2.3;\n"] ],
        [ 'No::CrazyChars' => qq["\npackage No::CrazyChars\[0\];\n"] ],
        )
    {
        my ( $name, $content ) = @$test;

        subtest $name => sub {
            my $module = MetaCPAN::Document::Module->new( name => $name );

        SKIP: {
                skip( 'Perl 5.14 needed for package block compilation', 1 )
                    if $] < 5.014;
                ok eval "sub { no strict; $content }", "code compiles";
            }

            my ($hidden) = ( $name =~ /^No::/ ? 1 : 0 );

            is $module->hide_from_pause($content), $hidden,
                "hide_from_pause is $hidden";
        };
    }
};

done_testing;
