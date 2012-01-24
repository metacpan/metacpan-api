use Test::More;
use strict;
use warnings;

use MetaCPAN::Model;

my $model   = MetaCPAN::Model->new( es => ':9900' );
my $idx     = $model->index('cpan');
my $release = $idx->type('distribution')->get('Moose');

is($release->name, 'Moose', 'Got correct release');

is($release->rt_bug_count, 39, 'Got correct bug count');

done_testing;
