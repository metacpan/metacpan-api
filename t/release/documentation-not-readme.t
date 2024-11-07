use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::TestHelpers qw( test_release );
use MetaCPAN::Util        qw( true false );
use Test::More;

test_release(
    'RWSTAUNER/Documentation-Not-Readme-0.01',
    {
        first       => true,
        extra_tests => \&test_modules,
        main_module => 'Documentation::Not::Readme',
    }
);

sub test_modules {
    my ($self) = @_;

    my @files = @{ $self->module_files };
    is( @files, 1, 'includes one file with modules' );

    my $file = shift @files;
    is( @{ $file->module }, 1, 'file contains one module' );

    my ($indexed) = grep { $_->{indexed} } @{ $file->module };

    is( $indexed->name,       'Documentation::Not::Readme', 'module name' );
    is( $file->documentation, 'Documentation::Not::Readme', 'documentation' );

    is( $indexed->associated_pod,
        'RWSTAUNER/Documentation-Not-Readme-0.01/lib/Documentation/Not/Readme.pm'
    );
}

done_testing;
