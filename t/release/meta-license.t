use Test::More;
use strict;
use warnings;

use MetaCPAN::Server::Test;
use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    'RWSTAUNER/Meta-License-Single-1.0',
    { license => [qw( mit )], },
    'Meta file lists one license',
);

test_release(
    'RWSTAUNER/Meta-License-Dual-1.0',
    { license => [qw( perl_5 bsd )], },
    'Meta file lists two licenses',
);

done_testing;
