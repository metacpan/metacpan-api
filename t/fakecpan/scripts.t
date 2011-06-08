use Test::More;
use strict;
use warnings;

use MetaCPAN::Model;

my $model   = MetaCPAN::Model->new( es => ':9900' );
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {   author => 'MO',
        name   => 'Scripts-0.01'
    } );

is( $release->name, 'Scripts-0.01', 'name ok' );

is( $release->author, 'MO', 'author ok' );

{
    my @files =
      $idx->type('file')->filter( { term => { mime => 'text/x-script.perl' } } )
      ->all;
    is( @files, 6, 'five scripts found' );
    @files = sort { $a->name cmp $b->name } grep { $_->documentation } @files;
    is( @files, 2, 'two with documentation' );
    is_deeply(
        [
            map {
                {   documentation => $_->documentation,
                    indexed       => $_->indexed,
                    mime          => $_->mime }
              } @files
        ],
        [
            {   documentation => 'catalyst',
                indexed       => 1,
                mime          => 'text/x-script.perl'
            },
            {   documentation => 'starman',
                indexed       => 1,
                mime          => 'text/x-script.perl'
            }
        ],
        'what is to be expected' );
}

done_testing;
