use strict;
use warnings;

use FindBin;
use MetaCPAN::Model::Release;
use MetaCPAN::Script::Runner;
use MetaCPAN::TestHelpers qw( get_config );
use Test::Most;

my $config = get_config();

subtest 'basic dependencies' => sub {
    my $file
        = 't/var/tmp/fakecpan/authors/id/M/MS/MSCHWERN/Prereqs-Basic-0.01.tar.gz';

    my $release = MetaCPAN::Model::Release->new(
        logger => $config->{logger},
        level  => $config->{level},
        file   => $file,
    );
    $release->set_logger_once;

    my $dependencies = $release->dependencies;

    cmp_bag $dependencies,
        [
        {
            phase        => 'build',
            relationship => 'requires',
            module       => 'For::Build::Requires1',
            version      => 2.45
        },
        {
            phase        => 'configure',
            relationship => 'requires',
            module       => 'For::Configure::Requires1',
            version      => 72
        },
        {
            phase        => 'runtime',
            relationship => 'requires',
            module       => 'For::Runtime::Requires1',
            version      => 0
        },
        {
            phase        => 'runtime',
            relationship => 'requires',
            module       => 'For::Runtime::Requires2',
            version      => 1.23
        },
        {
            phase        => 'runtime',
            relationship => 'recommends',
            module       => 'For::Runtime::Recommends1',
            version      => 0
        }
        ];
};

done_testing;
