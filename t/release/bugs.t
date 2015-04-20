use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More;

test_distribution(
    'Moose',
    {
        bugs => {
            type => 'rt',
            source =>
                'https://rt.cpan.org/Public/Dist/Display.html?Name=Moose',
            new      => 15,
            open     => 20,
            stalled  => 4,
            patched  => 0,
            resolved => 122,
            rejected => 23,
            active   => 39,
            closed   => 145,
        },
    },
    'Test bug data for Moose dist',
);

done_testing;
