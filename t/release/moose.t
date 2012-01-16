use Test::More;
use strict;
use warnings;

use MetaCPAN::Model;

my $model   = MetaCPAN::Model->new( es => ':9900' );
my $idx     = $model->index('cpan');
my @moose = $idx->type('release')->filter(
    {   term => { 'release.distribution' => 'Moose' }
    }
)->all;

my $first = 0;
map { $first++ } grep { $_->first } @moose;

ok($first, 'only one moose is first');

done_testing;