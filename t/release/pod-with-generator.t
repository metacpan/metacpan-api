use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS ();
use MetaCPAN::TestHelpers;
use Test::More;

test_release(
    {
        name        => 'Pod-With-Generator-1',
        author      => 'BORISNAT',
        authorized  => 1,
        first       => 1,
        provides    => [ 'Pod::With::Generator', ],
        main_module => 'Pod::With::Generator',
        modules     => {
            'lib/Pod/With/Generator.pm' => [
                {
                    name             => 'Pod::With::Generator',
                    indexed          => Cpanel::JSON::XS::true(),
                    authorized       => Cpanel::JSON::XS::true(),
                    version          => '1',
                    version_numified => 1,
                    associated_pod =>
                        'BORISNAT/Pod-With-Generator-1/lib/Pod/With/Generator.pm',
                },
            ],
        },
        extra_tests => \&test_assoc_pod,
    }
);

sub test_assoc_pod {
    my ($self) = @_;

    my $mod = $self->module_files->[0];

    is $mod->sloc, 3, 'sloc';
    is $mod->slop, 5, 'slop';

    is_deeply $mod->{pod_lines},
        [ [ 5, 9 ], ],
        'pod lines determined correctly';

    my $pod_file  = $self->file_content($mod);
    my $generator = $self->file_content('config/doc_gen.pm');

    my $real_pod = qr/this is the real one/;
    like $pod_file,    $real_pod, 'real pod from real file';
    unlike $generator, $real_pod, 'not in generator';

    my $gen_text = qr/not the real abstract/;
    unlike $pod_file, $gen_text, 'pod does not have generator comment';
    like $generator,  $gen_text, 'generator has comment';

    is ${ $mod->pod },
        q[NAME Pod::With::Generator - this pod is generated Truth but this is the real one!],
        'pod text';

}

done_testing;
