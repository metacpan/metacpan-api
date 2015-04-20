use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

my $model   = model();
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {
        author => 'MO',
        name   => 'Documentation-Hide-0.01'
    }
);

is( $release->name, 'Documentation-Hide-0.01', 'name ok' );

is( $release->author, 'MO', 'author ok' );

ok( $release->first, 'Release is first' );

{
    my @files = $idx->type('file')->filter(
        {
            and => [
                { term   => { 'file.author'  => $release->author } },
                { term   => { 'file.release' => $release->name } },
                { exists => { field          => 'file.module.name' } },
            ]
        }
    )->all;

    is( @files, 1, 'includes one file with modules' );

    my $file = shift @files;
    is( @{ $file->module }, 1, 'file contains one module' );

    my ($indexed) = grep { $_->{indexed} } @{ $file->module };
    is( $indexed->name,       'Documentation::Hide', 'module name ok' );
    is( $file->documentation, 'Documentation::Hide', 'documentation ok' );

    is ${ $file->pod },
        q[NAME Documentation::Hide::Internal - abstract], 'pod text';
}

{
    my @files = $idx->type('file')->filter(
        {
            and => [
                { term   => { author  => $release->author } },
                { term   => { release => $release->name } },
                { exists => { field   => 'file.documentation' } }
            ]
        }
    )->all;
    is( @files, 2, 'two files with documentation' );
}

done_testing;
