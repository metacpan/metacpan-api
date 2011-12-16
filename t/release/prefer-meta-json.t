use Test::More;
use strict;
use warnings;

use MetaCPAN::Model;

my $model   = MetaCPAN::Model->new( es => ':9900' );
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {   author => 'LOCAL',
        name   => 'Prefer-Meta-JSON-1.1'
    }
);

is( $release->name, 'Prefer-Meta-JSON-1.1', 'name ok' );
is( $release->distribution, 'Prefer-Meta-JSON', 'distribution ok' );
is( $release->author, 'LOCAL', 'author ok' );
ok( $release->first, 'Release is first');

{
    my @files = $idx->type('file')->filter(
        {   and => [
                { term   => { 'file.author'  => $release->author } },
                { term   => { 'file.release' => $release->name } },
                { exists => { field          => 'file.module.name' } },
            ]
        }
    )->all;
    is( @files, 1, 'includes one file with modules' );

    my $file = shift @files;
    is( $file->documentation, 'Prefer::Meta::JSON', 'documentation ok' );

    my @modules = @{ $file->module };

    is( scalar @modules, 2, 'file contains two modules' );

    is( $modules[0]->name,    'Prefer::Meta::JSON', 'module name ok' );
    is( $modules[0]->indexed, 1, 'main module indexed' );

    is( $modules[1]->name,    'Prefer::Meta::JSON::Gremlin', 'module name ok' );
    is( $modules[1]->indexed, 0, 'module not indexed' );
}

done_testing;
