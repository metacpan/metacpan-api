use Test::More;
use strict;
use warnings;

use MetaCPAN::Model;

my $model   = MetaCPAN::Model->new( es => ':9900' );
my $idx     = $model->index('cpan');
my $release = $idx->type('distribution')->get('Moose');

is( $release->name, 'Moose', 'Got correct release' );

is( $release->bugs->{source}, 'https://rt.cpan.org/Public/Dist/Display.html?Name=Moose' );
is( $release->bugs->{active},  39, 'Got correct bug count (active)' );
is( $release->bugs->{stalled}, 4,  'Got correct bug count (stalled)' );

done_testing;
