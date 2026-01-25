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
                { term => { author => 'MO' } },
                { term => { name   => 'Scripts-0.01' } },
            ],
        },
    },
);

is( $release->{name}, 'Scripts-0.01', 'name ok' );

is( $release->{author}, 'MO', 'author ok' );

is( $release->{version}, '0.01', 'version ok' );

is( $release->{main_module}, 'Scripts', 'main_module ok' );

{
    my @files = es_result(
        file => {
            bool => {
                must => [
                    { term => { mime         => 'text/x-script.perl' } },
                    { term => { distribution => 'Scripts' } },
                ],
            },
        }
    );
    is( @files, 4, 'four scripts found' );
    @files = sort { $a->{name} cmp $b->{name} }
        grep { exists $_->{documentation} } @files;
    is( @files, 2, 'two with documentation' );
    is_deeply(
        [
            map { {
                documentation => $_->{documentation},
                indexed       => $_->{indexed},
                mime          => $_->{mime},
            } } @files
        ],
        [
            {
                documentation => 'catalyst',
                indexed       => true,
                mime          => 'text/x-script.perl'
            },
            {
                documentation => 'starman',
                indexed       => true,
                mime          => 'text/x-script.perl'
            }
        ],
        'what is to be expected'
    );

    foreach my $file (@files) {
        like $file->{pod},
            qr/\ANAME (catalyst|starman) - starter\z/,
            $file->{path} . ' pod text';
    }
}

done_testing;
