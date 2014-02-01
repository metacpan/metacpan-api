use strict;
use warnings;
use Test::More;
use MetaCPAN::Server ();
my $c = 'MetaCPAN::Server';

foreach my $test (
    [   LOCAL => 'Multiple-Modules-0.1',
        [qw( Multiple::Modules Multiple::Modules::Deprecated )],
        []
    ],
    [   LOCAL => 'Multiple-Modules-1.01',
        [   qw( Multiple::Modules Multiple::Modules::A Multiple::Modules::A2 Multiple::Modules::B )
        ],
        [qw( Multiple::Modules::B::Secret )]
    ],
    [   LOCAL => 'Multiple-Modules-RDeps-2.03',
        [qw( Multiple::Modules::RDeps )],
        []
    ],
    [   LOCAL => 'Multiple-Modules-RDeps-A-2.03',
        [qw( Multiple::Modules::RDeps::A )],
        []
    ],
    )
{
    my ( $author, $release, $indexed, $extra ) = @$test;
    my $find = { author => $author, name => $release };
    is_deeply [
        sort
            map { $_->{name} }
            map { @{ $_->{_source}->{module} } } @{
            $c->model('CPAN::File')->raw->find_provided_by($find)
                ->{hits}{hits}
            }
        ],
        [ sort( @$indexed, @$extra ) ],
        'got all included modules';

    is_deeply
        [
        sort $c->model('CPAN::File')
            ->raw->find_module_names_provided_by($find) ],
        [ sort @$indexed ],
        'got only the module names expected';
}

done_testing;
