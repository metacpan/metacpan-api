use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    {
        name       => 'Packages-1.103',
        author     => 'RWSTAUNER',
        abstract   => 'Package examples',
        authorized => \1,
        first      => \1,
        provides   => [ 'Packages', 'Packages::BOM', ],
        status     => 'latest',

        modules => {
            'lib/Packages.pm' => [
                {
                    name             => 'Packages',
                    indexed          => \1,
                    authorized       => \1,
                    version          => '1.103',
                    version_numified => 1.103,
                    associated_pod =>
                        'RWSTAUNER/Packages-1.103/lib/Packages.pm',
                },
            ],
            'lib/Packages/BOM.pm' => [
                {
                    name             => 'Packages::BOM',
                    indexed          => \1,
                    authorized       => \1,
                    version          => 0.04,
                    version_numified => 0.04,
                    associated_pod =>
                        'RWSTAUNER/Packages-1.103/lib/Packages/BOM.pm',
                },
            ],
        },
        extra_tests => sub {

            # I couldn't get the Source model to work outside the app (I got
            # "No handler available for type 'application/octet-stream'",
            # strangely), so just do the http request.
            test_psgi app, sub {
                my $cb = shift;
                my $content
                    = $cb->(
                    GET '/source/RWSTAUNER/Packages-1.103/lib/Packages/BOM.pm'
                    )->content;
                like $content, qr/\A\xef\xbb\xbfpackage Packages::BOM;\n/,
                    'Packages::BOM module starts with UTF-8 BOM';
            };
        },
    },
    'Test Packages release and its modules',
);

done_testing;
