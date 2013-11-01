use Test::More;
use strict;
use warnings;

use MetaCPAN::Server::Test;

# Work around an issue with JSON::XS 3.0 and the accompanying JSON 2.9 release.
# (Test::More::is_deeply with stringiying objects says 1 != '1'.)
my $true = JSON::decode_json('{"bool": true}')->{bool};
# This is stupid, but it works; JSON 2.61 overloaded eq, 2.9 stopped.
$true = '1' if $true eq 'true';

my $model   = model();
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {   author => 'MO',
        name   => 'Scripts-0.01'
    }
);

is( $release->name, 'Scripts-0.01', 'name ok' );

is( $release->author, 'MO', 'author ok' );

is( $release->version, '0.01', 'version ok' );

{
    my @files = $idx->type('file')->filter(
        {   and => [
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
        [   map {
                {   documentation => $_->documentation,
                    indexed       => $_->indexed,
                    mime          => $_->mime
                }
                } @files
        ],
        [   {   documentation => 'catalyst',
                indexed       => $true,
                mime          => 'text/x-script.perl'
            },
            {   documentation => 'starman',
                indexed       => $true,
                mime          => 'text/x-script.perl'
            }
        ],
        'what is to be expected'
    );
}

done_testing;
