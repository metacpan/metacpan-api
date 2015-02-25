use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    'RWSTAUNER/Meta-License-Single-1.0',
    {
        license     => [qw( mit )],
        main_module => 'Meta::License::Single',
    },
    'Meta file lists one license',
);

test_release(
    'RWSTAUNER/Meta-License-Dual-1.0',
    {
        license     => [qw( perl_5 bsd )],
        main_module => 'Meta::License::Dual',
    },
    'Meta file lists two licenses',
);

done_testing;
