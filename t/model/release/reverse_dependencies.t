use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server ();

use Test::More;

my $c = MetaCPAN::Server::;

subtest 'distribution reverse_dependencies' => sub {
    my $data = [
        sort { $a->[1] cmp $b->[1] }
            map +[ @{$_}{qw(author name)} ],
        @{
            $c->model('ESQuery')
                ->release->reverse_dependencies('Multiple-Modules')->{data}
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

subtest 'module reverse_dependencies' => sub {
    my $data = [
        map +[ @{$_}{qw(author name)} ],
        @{
            $c->model('ESQuery')->release->requires('Multiple::Modules')
                ->{data}
        }
    ];

    is_deeply(
        $data,
        [ [ LOCAL => 'Multiple-Modules-RDeps-2.03' ], ],
        'Got correct reverse dependencies for module.'
    );
};

subtest 'no reverse_dependencies' => sub {
    my $data
        = $c->model('ESQuery')->release->requires('DoesNotExist')->{data};

    is_deeply( $data, [], 'Found no reverse dependencies for module.' );
};

done_testing;
