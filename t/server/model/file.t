use strict;
use warnings;
use Test::More;
use MetaCPAN::Server ();
my $c = 'MetaCPAN::Server';

foreach my $test (
    [
        'Multiple-Modules',
        [qw( Multiple::Modules Multiple::Modules::A Multiple::Modules::A2 Multiple::Modules::B )],
        [qw( Multiple::Modules::B::Secret )]
    ],
    [
        'Multiple-Modules-RDeps',
        [qw( Multiple::Modules::RDeps )],
        []
    ],
    [
        'Multiple-Modules-RDeps-A',
        [qw( Multiple::Modules::RDeps::A )],
        []
    ],
){
    my ( $release, $indexed, $extra ) = @$test;
    is_deeply
        [
            sort
            map  { $_->{name} }
            map  { @{ $_->{_source}->{module} } }
            @{ $c->model('CPAN::File')->raw->find_provided_by( $release )->{hits}{hits} }
        ],
        [ sort( @$indexed, @$extra ) ],
        'got all included modules';

    is_deeply
        [ sort $c->model('CPAN::File')->raw->find_module_names_provided_by( $release ) ],
        [ sort @$indexed ],
        'got only the module names expected';
}

done_testing;
