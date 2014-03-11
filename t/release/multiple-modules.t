use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

my $model   = model();
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {   author => 'LOCAL',
        name   => 'Multiple-Modules-1.01'
    }
);

is( $release->abstract, 'abstract', 'abstract set from Multiple::Modules' );

is( $release->name, 'Multiple-Modules-1.01', 'name ok' );

is( $release->author, 'LOCAL', 'author ok' );

is_deeply(
    [ sort @{ $release->provides } ],
    [   sort "Multiple::Modules", "Multiple::Modules::A",
        "Multiple::Modules::A2",  "Multiple::Modules::B"
    ],
    'provides ok'
);

# This test depends on files being indexed in the right order
# which depends on the mtime of the files.
ok( !$release->first, 'Release is not first' );

{
    my @files = $idx->type('file')->filter(
        {   and => [
                { term   => { 'file.author'  => $release->author } },
                { term   => { 'file.release' => $release->name } },
                { exists => { field          => 'file.module.name' } },
            ]
        }
    )->all;
    is( @files, 3, 'includes three files with modules' );

    @files = sort { $a->{name} cmp $b->{name} } @files;

    foreach my $test (
        [   'A.pm',
            'Multiple::Modules::A',
            [   { name => 'Multiple::Modules::A',  indexed => 1 },
                { name => 'Multiple::Modules::A2', indexed => 1 },
            ]
        ],
        [   'B.pm',
            'Multiple::Modules::B',
            [   { name => 'Multiple::Modules::B', indexed => 1 },

                #{name => 'Multiple::Modules::_B2', indexed => 0}, # hidden
                { name => 'Multiple::Modules::B::Secret', indexed => 0 },
            ]
        ],
        [   'Modules.pm',
            'Multiple::Modules',
            [ { name => 'Multiple::Modules', indexed => 1 }, ]
        ],
        )
    {
        my ( $basename, $doc, $expmods ) = @$test;

        my $file = shift @files;
        is( $file->name,          $basename, 'file name' );
        is( $file->documentation, $doc,      'documentation ok' );

        is( scalar @{ $file->module },
            scalar @$expmods,
            'correct number of modules'
        );

        foreach my $expmod (@$expmods) {
            my $mod = shift @{ $file->module };
            if ( !$mod ) {
                ok( 0, "module not found when expecting: $expmod->{name}" );
                next;
            }
            is( $mod->name, $expmod->{name}, 'module name ok' );
            is( $mod->indexed, $expmod->{indexed},
                'module indexed (or not)' );
        }

        is( scalar @{ $file->module }, 0, 'all mods tested' );
    }
}

$release = $idx->type('release')->get(
    {   author => 'LOCAL',
        name   => 'Multiple-Modules-0.1'
    }
);
ok $release, 'got older version of release';
ok $release->first, 'this version was first';

ok( my $file = $idx->type('file')->filter(
        {   and => [
                { term => { release       => 'Multiple-Modules-0.1' } },
                { term => { documentation => 'Moose' } }
            ]
        }
        )->first,
    'get Moose.pm'
);

ok( my ($moose) = ( grep { $_->name eq 'Moose' } @{ $file->module } ),
    'find Moose module in old release' )
    or diag( Test::More::explain( { file_module => $file->module } ) );

$moose
    and ok( !$moose->authorized, 'Moose is not authorized' );

$release
    and ok( !$release->authorized, 'release is not authorized' );

done_testing;
