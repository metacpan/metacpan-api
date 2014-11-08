use Test::More;
use strict;
use warnings;

use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    {
        name       => 'Pod-With-Data-Token-0.01',
        author     => 'BORISNAT',
        authorized => \1,
        first      => \1,
        provides   => [ 'Pod::With::Data::Token', ],
        modules    => {
            'lib/Pod/With/Data/Token.pm' => [
                {
                    name             => 'Pod::With::Data::Token',
                    indexed          => \1,
                    authorized       => \1,
                    version          => '0.01',
                    version_numified => 0.01,
                    associated_pod =>
                        'BORISNAT/Pod-With-Data-Token-0.01/lib/Pod/With/Data/Token.pm',
                },
            ],
        },
        extra_tests => \&test_content,
    }
);

sub test_content {
    my ($self) = @_;

    my $mod = $self->module_files->[0];

    is $mod->sloc, 5,  'sloc';
    is $mod->slop, 17, 'slop';

    is_deeply $mod->{pod_lines},
        #<<<
        [
            [5, 20],
            [30, 5],
            [45, 3],
        ],
        #>>>
        'pod lines determined correctly';

    my $content = $self->file_content($mod);

    like $content,
        qr!\n=head1 SYNOPSIS\n\n\s+use warnings;\n\s+print <DATA>;\n\x20\x20__DATA__\n\s+More text\n!,
        '__DATA__ token in verbatim pod in tact';

    like $content,
        qr!\n=head1 DESCRIPTION\n\ndata handle inside pod is pod but not data\n\n__DATA__\n\nsee\?\n\n=cut!,
        '^__DATA__ token in pod paragraph in tact';

    like $content,
        qr!\n__DATA__\n\ndata is here\n\n__END__\n\nTHE END IS NEAR\n\n\n=pod\n\nthis is pod!,
        'actual __DATA__ and __END__ tokens in tact (with closing pod)';
}

done_testing;
