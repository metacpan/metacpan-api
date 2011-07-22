use Test::More;
use strict;
use warnings;

use MetaCPAN::Model;

my $model   = MetaCPAN::Model->new( es => ':9200' );
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {   author => 'LOCAL',
        name   => 'Some-1.00-TRIAL'
    }
);

is( $release->name, 'Some-1.00-TRIAL', 'name ok' );

is( $release->version, '1.00-TRIAL', 'version with trial suffix' );

done_testing;
