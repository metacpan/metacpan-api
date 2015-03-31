use Test::More;
use strict;
use warnings;

use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    {
        name       => 'Common-Files-1.1',
        author     => 'BORISNAT',
        authorized => \1,
        first      => \1,
        provides   => ['Common::Files'],
        modules    => {
            'lib/Common/Files.pm' => [
                {
                    name             => 'Common::Files',
                    indexed          => \1,
                    authorized       => \1,
                    version          => '1.1',
                    version_numified => 1.1,
                    associated_pod =>
                        'BORISNAT/Common-Files-1.1/lib/Common/Files.pm',
                },
            ],
        },
        extra_tests => sub {
            my ($self) = @_;

            {
                my $file = $self->file_by_path('Makefile.PL');

                ok !$file->indexed, 'Makefile.PL not indexed';
                ok $file->authorized,
                    'Makefile.PL authorized, i suppose (not *un*authorized)';
                is $file->sloc, 1, 'sloc';
                is $file->slop, 3, 'slop';

                is scalar( @{ $file->pod_lines } ), 1, 'one pod section';

                is $file->abstract, undef, 'no abstract';
            }

        },
    }
);

done_testing;
