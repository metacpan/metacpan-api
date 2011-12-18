use strict;
use warnings;
use Test::More;
use MetaCPAN::Server ();
my $c = 'MetaCPAN::Server';

is_deeply
    [
        sort
        map  { $_->{name} }
        map  { @{ $_->{_source}->{module} } }
        @{ $c->model('CPAN::File')->raw->find_provided_by('Multiple-Modules')->{hits}{hits} }
    ],
    [ sort qw( Multiple::Modules Multiple::Modules::A Multiple::Modules::A2 Multiple::Modules::B Multiple::Modules::B::Secret ) ],
    'got all included modules';

is_deeply
    [ sort @{ $c->model('CPAN::File')->raw->find_module_names_provided_by('Multiple-Modules') } ],
    [ sort qw( Multiple::Modules Multiple::Modules::A Multiple::Modules::A2 Multiple::Modules::B ) ],
    'got only the module names expected';

done_testing;
