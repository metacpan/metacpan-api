use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Query::Search ();
use MetaCPAN::TestServer    ();
use MetaCPAN::Util          qw(true false);
use Test::Deep              qw( cmp_deeply ignore );
use Test::More;

# Just use this to get an es object.
my $server = MetaCPAN::TestServer->new;
my $search = MetaCPAN::Query::Search->new( es => $server->es_client, );

ok( $search, 'search' );

{
    my $results = $search->search_web('Fooxxxx');
    cmp_deeply(
        $results,
        {
            results   => [],
            total     => 0,
            took      => ignore(),
            collapsed => true,
        },
        'no results on fake module'
    );
}

{
    my $collapsed_search = $search->search_web('Foo');
    is( scalar @{ $collapsed_search->{results}->[0]->{hits} },
        2, 'got results for collapsed search' );

    ok( $collapsed_search->{collapsed}, 'results are flagged as collapsed' );

    my $page      = 1;
    my $page_size = 20;
    my $collapsed = 0;

    my $expanded
        = $search->search_web( 'Foo', $page, $page_size, $collapsed );

    ok( !$expanded->{collapsed}, 'results are flagged as expanded' );

    is( $expanded->{results}->[0]->{hits}->[0]->{path},
        'lib/Pod/Pm.pm', 'first expanded result is expected' );
    is( $expanded->{results}->[1]->{hits}->[0]->{path},
        'lib/Pod/Pm/NoPod.pod', 'second expanded result is expected' );
}

{
    my $results = $search->search_web('author:Mo');
    is( @{ $results->{results} }, 5, '5 results on author search' );
}

{
    my $results = $search->search_web('author:Mo BadPod');
    isnt( @{ $results->{results} },
        0, '>0 results on author search with extra' );
}

{
    eval { $search->search_web('usr/bin/env') };
    is( $@, '', 'search term with a / no exception' );
}

{
    my $long_form  = $search->search_web('distribution:Pod-Pm');
    my $short_form = $search->search_web('dist:Pod-Pm');

    cmp_deeply(
        $long_form->{results},
        $short_form->{results},
        'dist == distribution search'
    );
}

{
    my $module  = 'Binary::Data::WithPod';
    my $results = $search->search_web($module);
    is(
        $results->{results}->[0]->{hits}->[0]->{description},
        'razzberry pudding',
        'description included in results'
    );
}

done_testing();
