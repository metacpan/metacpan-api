use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( es_result );
use Test::More;

my $release = es_result(
    release => {
        bool => {
            must => [
                { term => { author => 'MO' } },
                { term => { name   => 'Documentation-Hide-0.01' } },
            ],
        },
    },
);

is( $release->{name}, 'Documentation-Hide-0.01', 'name ok' );

is( $release->{author}, 'MO', 'author ok' );

is( $release->{main_module}, 'Documentation::Hide', 'main_module ok' );

ok( $release->{first}, 'Release is first' );

{
    my @files = es_result(
        file => {
            bool => {
                must => [
                    { term   => { author  => $release->{author} } },
                    { term   => { release => $release->{name} } },
                    { exists => { field   => 'module.name' } },
                ],
            },
        }
    );

    is( @files, 1, 'includes one file with modules' );

    my $file = shift @files;
    is( @{ $file->{module} }, 1, 'file contains one module' );

    my ($indexed) = grep { $_->{indexed} } @{ $file->{module} };
    is( $indexed->{name},       'Documentation::Hide', 'module name ok' );
    is( $file->{documentation}, 'Documentation::Hide', 'documentation ok' );

    is $file->{pod},
        q[NAME Documentation::Hide::Internal - abstract], 'pod text';
}

{
    my @files = es_result(
        file => {
            bool => {
                must => [
                    { term   => { author  => $release->{author} } },
                    { term   => { release => $release->{name} } },
                    { exists => { field   => 'documentation' } }
                ],
            },
        }
    );
    is( @files, 2, 'two files with documentation' );
}

done_testing;
