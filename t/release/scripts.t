use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More skip_all => 'Scripting is disabled';

my $model   = model();
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {
        author => 'MO',
        name   => 'Scripts-0.01'
    }
);

is( $release->name, 'Scripts-0.01', 'name ok' );

is( $release->author, 'MO', 'author ok' );

is( $release->version, '0.01', 'version ok' );

{
    my @files = $idx->type('file')->filter(
        {
            and => [
                { term => { mime         => 'text/x-script.perl' } },
                { term => { distribution => 'Scripts' } }
            ]
        }
    )->all;
    is( @files, 4, 'four scripts found' );
    @files = sort { $a->name cmp $b->name }
        grep { $_->has_documentation } @files;
    is( @files, 2, 'two with documentation' );
    is_deeply(
        [
            map {
                {
                    documentation => $_->documentation,
                    indexed       => $_->indexed,
                    mime          => $_->mime
                }
            } @files
        ],
        [
            {
                documentation => 'catalyst',
                indexed       => \1,
                mime          => 'text/x-script.perl'
            },
            {
                documentation => 'starman',
                indexed       => \1,
                mime          => 'text/x-script.perl'
            }
        ],
        'what is to be expected'
    );

    foreach my $file (@files) {
        like ${ $file->pod },
            qr/\ANAME (catalyst|starman) - starter\z/,
            $file->path . ' pod text';
    }
}

done_testing;
