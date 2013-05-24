use Test::More;
use strict;
use warnings;

use MetaCPAN::Server::Test;

my $model   = model();
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {   author => 'LOCAL',
        name   => 'Some-1.00-TRIAL'
    }
);

is( $release->name, 'Some-1.00-TRIAL', 'name ok' );

is( $release->version, '1.00-TRIAL', 'version with trial suffix' );

# although the author is not listed in the 06perms file but the 02packages.details file
ok( $release->authorized, 'release is authorized' );

done_testing;
