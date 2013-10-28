use Test::More;
use strict;
use warnings;

use MetaCPAN::Server::Test;

my $model   = model();
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get({
    author => 'RWSTAUNER',
    name   => 'Meta-Provides-1.01'
});

is( $release->abstract, 'has provides key in meta', 'abstract set from module');
is( $release->name, 'Meta-Provides-1.01', 'name ok' );
is( $release->author, 'RWSTAUNER', 'author ok' );
ok( $release->authorized, 'release is authorized' );

is_deeply
    [sort @{$release->provides}],
    [sort qw( Meta::Provides )],
    'provides matches meta key';

{
    my @files = $idx->type('file')->filter({
        and => [
            { term   => { 'author'  => $release->author } },
            { term   => { 'release' => $release->name } },
            { term   => { 'directory' => \0 } },
            { prefix => { 'path'         => 'lib/' } },
        ]
    })->all;
    is( @files, 2, 'two files found in lib/' );

    @files = sort { $a->{name} cmp $b->{name} } @files;

    {
        my $not_indexed = shift @files;
        is $not_indexed->name, 'NotSpecified.pm', 'matching file name';
        is @{ $not_indexed->module }, 0, 'no modules (file not parsed)';
    }

    foreach my $test (
        ['Provides.pm', 'Meta::Provides', [
            {name => 'Meta::Provides', indexed => 1},
        ]],
    ){
        my ($basename, $doc, $expmods) = @$test;

        my $file = shift @files;
        ok $file, "file present (expecting $basename)"
            or next;

        is( $file->name,           $basename, 'file name' );
        is( $file->documentation,  $doc,      'documentation ok' );

        is( scalar @{ $file->module },
            scalar @$expmods,
            'correct number of modules' );

        foreach my $expmod ( @$expmods ){
            my $mod = shift @{ $file->module };
            ok $mod, "module present (expecting $expmod)"
                or next;
            is( $mod->name,    $expmod->{name},    'module name ok' );
            is( $mod->indexed, $expmod->{indexed}, 'module indexed (or not)' );
        }

        is( scalar @{ $file->module }, 0, 'all mods tested' );
    }
}

done_testing;
