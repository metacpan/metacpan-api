use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

my $model   = model();
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get(
    {
        author      => 'LOCAL',
        name        => 'Some-1.00-TRIAL',
        main_module => 'Some',
    }
);

is( $release->name, 'Some-1.00-TRIAL', 'name ok' );

is( $release->version, '1.00-TRIAL', 'version with trial suffix' );

# although the author is not listed in the 06perms file but the 02packages.details file
ok( $release->authorized, 'release is authorized' );

is_deeply $release->tests,
    {
    pass    => 4,
    fail    => 3,
    na      => 2,
    unknown => 1,
    },
    'cpantesters results';

done_testing;
