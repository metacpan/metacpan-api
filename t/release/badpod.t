use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS ();
use MetaCPAN::TestHelpers qw( test_release );
use Test::More;

test_release(
    {
        name        => 'BadPod-0.01',
        author      => 'MO',
        authorized  => 1,
        first       => 1,
        provides    => [ 'BadPod', ],
        main_module => 'BadPod',
        modules     => {
            'lib/BadPod.pm' => [
                {
                    name             => 'BadPod',
                    indexed          => Cpanel::JSON::XS::true(),
                    authorized       => Cpanel::JSON::XS::true(),
                    version          => '0.01',
                    version_numified => 0.01,
                    associated_pod   => 'MO/BadPod-0.01/lib/BadPod.pm',
                },
            ],
        },
        extra_tests => \&test_bad_pod,
    }
);

sub test_bad_pod {
    my ($self) = @_;

    my $file = $self->file_by_path('lib/BadPod.pm');

    is $file->sloc, 3, 'sloc';
    is $file->slop, 4, 'slop';

    is_deeply $file->pod_lines, [ [ 5, 7 ], ], 'no pod_lines';

    is ${ $file->pod },

        # The unknown "=head" directive will get dropped
        # but the paragraph following it is valid.
        q[NAME BadPod - Malformed POD There is no "more."], 'pod text';
}

done_testing;
