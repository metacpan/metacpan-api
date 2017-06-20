use strict;
use warnings;

use MetaCPAN::Server ();
use Test::More;

my $c = 'MetaCPAN::Server';

subtest 'reverse_dependencies' => sub {
    my $data = [
        sort { $a->[1] cmp $b->[1] }
            map +[ @{$_}{qw(author name)} ],
        @{
            $c->model('CPAN::Release')
                ->raw->reverse_dependencies('Multiple-Modules')->{data}
        }
    ];

    is_deeply(
        $data,
        [
            [ LOCAL => 'Multiple-Modules-RDeps-2.03' ],
            [ LOCAL => 'Multiple-Modules-RDeps-A-2.03' ],
        ],
        'Got correct reverse dependencies for distribution.'
    );
};

subtest 'reverse_dependencies' => sub {
    my $data = [
        map +[ @{$_}{qw(author name)} ],
        @{
            $c->model('CPAN::Release')->raw->requires('Multiple::Modules')
                ->{data}
        }
    ];

    is_deeply(
        $data,
        [ [ LOCAL => 'Multiple-Modules-RDeps-2.03' ], ],
        'Got correct reverse dependencies for module.'
    );
};

done_testing;
