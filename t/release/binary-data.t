use strict;
use warnings;

use lib 't/lib';
use MetaCPAN::TestHelpers;
use Test::More;

test_release(
    {
        name        => 'Binary-Data-0.01',
        author      => 'BORISNAT',
        authorized  => 1,
        first       => 1,
        provides    => [ 'Binary::Data', 'Binary::Data::WithPod', ],
        main_module => 'Binary::Data',
        modules     => {
            'lib/Binary/Data.pm' => [
                {
                    name             => 'Binary::Data',
                    indexed          => 'true',
                    authorized       => 'true',
                    version          => '0.01',
                    version_numified => 0.01,

                    # no associated_pod
                },
            ],
            'lib/Binary/Data/WithPod.pm' => [
                {
                    name             => 'Binary::Data::WithPod',
                    indexed          => 'true',
                    authorized       => 'true',
                    version          => '0.02',
                    version_numified => 0.02,
                    associated_pod =>
                        'BORISNAT/Binary-Data-0.01/lib/Binary/Data/WithPod.pm',
                },
            ],
        },
        extra_tests => \&test_binary_data,
    }
);

sub test_binary_data {
    my ($self) = @_;

    {
        my $file = $self->file_by_path('lib/Binary/Data.pm');

        is $file->sloc, 4, 'sloc';
        is $file->slop, 0, 'slop';

        is_deeply $file->{pod_lines}, [], 'no pod_lines';

        my $binary = $self->file_content($file);
        like $binary, qr/^=[a-zA-Z]/m, 'matches loose pod pattern';

        is ${ $file->pod }, q[], 'no pod text';
    }

    {
        my $file = $self->file_by_path('lib/Binary/Data/WithPod.pm');

        is $file->sloc, 4, 'sloc';
        is $file->slop, 7, 'slop';

        is_deeply $file->{pod_lines}, [ [ 5, 5 ], [ 22, 6 ], ], 'pod_lines';

        my $binary = $self->file_content($file);
        like $binary, qr/^=F/m, 'matches simple unwanted pod pattern';
        like $binary, qr/^=buzz9\xF0\x9F\x98\x8E/m,
            'matches more complex unwanted pod pattern';

        is ${ $file->pod },
            q[NAME Binary::Data::WithPod - that's it DESCRIPTION razzberry pudding],
            'pod text';
    }
}

done_testing;
