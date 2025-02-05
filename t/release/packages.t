use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::TestHelpers qw( test_release );
use MetaCPAN::Util        qw(true false);
use Test::More;

test_release(
    {
        name        => 'Packages-1.103',
        author      => 'RWSTAUNER',
        abstract    => 'Package examples',
        authorized  => true,
        first       => true,
        provides    => [ 'Packages', 'Packages::BOM', ],
        status      => 'latest',
        main_module => 'Packages',
        modules     => {
            'lib/Packages.pm' => [
                {
                    name             => 'Packages',
                    indexed          => true,
                    authorized       => true,
                    version          => '1.103',
                    version_numified => 1.103,
                    associated_pod   =>
                        'RWSTAUNER/Packages-1.103/lib/Packages.pm',
                },
            ],
            'lib/Packages/BOM.pm' => [
                {
                    name             => 'Packages::BOM',
                    indexed          => true,
                    authorized       => true,
                    version          => 0.04,
                    version_numified => 0.04,
                    associated_pod   =>
                        'RWSTAUNER/Packages-1.103/lib/Packages/BOM.pm',
                },
            ],
        },
        extra_tests => sub {
            my $self    = shift;
            my $path    = 'lib/Packages/BOM.pm';
            my $content = $self->file_content($path);

            like $content, qr/\A\xef\xbb\xbfpackage Packages::BOM;\n/,
                'Packages::BOM module starts with UTF-8 BOM';

            my $file = $self->file_by_path($path);

            is $file->{pod},
                q[NAME Packages::BOM - package in a file with a BOM],
                'pod text';

            is_deeply $self->file_by_path('lib/Packages/None.pm')
                ->{module},
                [],
                'pm file has no packages';
        },
    },
    'Test Packages release and its modules',
);

done_testing;
