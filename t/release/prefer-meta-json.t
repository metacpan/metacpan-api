use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( es_result );
use MetaCPAN::Util         qw(true false);
use Test::More;

my $release = es_result(
    release => {
        bool => {
            must => [
                { term => { author => 'LOCAL' } },
                { term => { name   => 'Prefer-Meta-JSON-1.1' } },
            ],
        },
    },
);

is( $release->{name},         'Prefer-Meta-JSON-1.1', 'name ok' );
is( $release->{distribution}, 'Prefer-Meta-JSON',     'distribution ok' );
is( $release->{author},       'LOCAL',                'author ok' );
is( $release->{main_module},  'Prefer::Meta::JSON',   'main_module ok' );
ok( $release->{first}, 'Release is first' );

is( ref $release->{metadata}, 'HASH', 'comes with metadata in a hashref' );
is( $release->{metadata}->{'meta-spec'}{version},
    2, 'meta_spec version is 2' );

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
        },
    );
    is( @files, 1, 'includes one file with modules' );

    my $file = shift @files;
    is( $file->{documentation}, 'Prefer::Meta::JSON', 'documentation ok' );

    my @modules = @{ $file->{module} };

    is( scalar @modules, 2, 'file contains two modules' );

    is( $modules[0]->{name},    'Prefer::Meta::JSON', 'module name ok' );
    is( $modules[0]->{indexed}, true,                 'main module indexed' );

    is( $modules[1]->{name}, 'Prefer::Meta::JSON::Gremlin',
        'module name ok' );
    is( $modules[1]->{indexed}, false, 'module not indexed' );
}

done_testing;
