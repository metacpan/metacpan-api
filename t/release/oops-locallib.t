use Test::More;
use strict;
use warnings;

use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    {
        name        => 'Oops-LocalLib-0.01',
        author      => 'BORISNAT',
        authorized  => \1,
        first       => \1,
        provides    => [ 'Fruits', 'Oops::LocalLib', ],
        main_module => 'Oops::LocalLib',
        modules     => {
            'lib/Oops/LocalLib.pm' => [
                {
                    name             => 'Oops::LocalLib',
                    indexed          => \1,
                    authorized       => \1,
                    version          => '0.01',
                    version_numified => 0.01,
                    associated_pod =>
                        'BORISNAT/Oops-LocalLib-0.01/lib/Oops/LocalLib.pm',
                },
            ],
            'foreign/Fruits.pm' => [
                {
                    name             => 'Fruits',
                    indexed          => \1,
                    authorized       => \1,
                    version          => '1',
                    version_numified => 1,
                    associated_pod =>
                        'BORISNAT/Oops-LocalLib-0.01/foreign/Fruits.pm',
                },
            ],
        },
        extra_tests => sub {
            my ($self) = @_;

            {
                my $file = $self->file_by_path('local/Vegetable.pm');

                ok !$file->indexed, 'file in /local/ not indexed';
                ok $file->authorized, 'file in /local/ not un-authorized';
                is $file->sloc,       2, 'sloc';
                is $file->slop,       2, 'slop';

                is_deeply $file->{pod_lines}, [ [ 4, 3 ] ], 'pod_lines';

                is $file->abstract, q[should not have been included],
                    'abstract';
            }

        },
    }
);

done_testing;
