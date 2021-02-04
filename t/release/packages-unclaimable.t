use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS ();
use IO::String;
use List::MoreUtils qw( uniq );
use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers qw( test_release );
use Module::Metadata;
use Test::More;

test_release(
    {
        name     => 'Packages-Unclaimable-2',
        author   => 'RWSTAUNER',
        abstract =>
            'Dist that appears to declare packages that are not allowed',
        authorized  => 1,
        first       => 1,
        provides    => [ 'Packages::Unclaimable', ],
        status      => 'latest',
        main_module => 'Packages::Unclaimable',
        modules     => {
            'lib/Packages/Unclaimable.pm' => [
                {
                    name             => 'Packages::Unclaimable',
                    indexed          => Cpanel::JSON::XS::true(),
                    authorized       => Cpanel::JSON::XS::true(),
                    version          => 2,
                    version_numified => 2,
                    associated_pod   =>
                        'RWSTAUNER/Packages-Unclaimable-2/lib/Packages/Unclaimable.pm',
                },
            ],
        },

        extra_tests => sub {
            my ($self) = @_;

            ok $self->data->authorized, 'dist is authorized';

            my $content = $self->file_content('lib/Packages/Unclaimable.pm');

            my $mm
                = Module::Metadata->new_from_handle(
                IO::String->new($content),
                'lib/Packages/Unclaimable.pm' );

            is_deeply [ uniq sort $mm->packages_inside ],
                [ sort qw(Packages::Unclaimable main DB) ],
                'Module::Metadata finds the packages we ignore';
        },
    },
    'Packages::Unclaimable is authorized but ignores unclaimable packages',
);

done_testing;
