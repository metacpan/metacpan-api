use strict;
use warnings;

use MetaCPAN::Model::Search ();
use MetaCPAN::TestServer    ();
use Test::More;

# Just use this to get an es object.
my $server = MetaCPAN::TestServer->new;
my $search = MetaCPAN::Model::Search->new(
    es    => $server->es_client,
    index => 'cpan',
);

ok( $search,             'search' );
ok( $search->_not_rogue, '_not_rogue' );

{
    my $results = $search->search_web('Fooxxxx');
    is_deeply( $results, {}, 'no results on fake module' );
}

{
    my $collapsed_search = $search->search_web('Foo');
    is( scalar @{ $collapsed_search->{results}->[0] },
        2, 'got results for collapsed search' );

    ok(
        ${ $collapsed_search->{collapsed} },
        'results are flagged as collapsed'
    );

    my $from      = 0;
    my $page_size = 20;
    my $collapsed = 0;

    my $expanded
        = $search->search_web( 'Foo', $from, $page_size, $collapsed );

    ok( !${ $expanded->{collapsed} }, 'results are flagged as expanded' );

    is( $expanded->{results}->[0]->[0]->{path},
        'lib/Pod/Pm.pm', 'first expanded result is expected' );
    is( $expanded->{results}->[1]->[0]->{path},
        'lib/Pod/Pm/NoPod.pod', 'second expanded result is expected' );
}

{
    my $results = $search->search_web('author:Mo');
    is( @{ $results->{results} }, 5, '5 results on author search' );
}

{
    my $long_form  = $search->search_web('distribution:Pod-Pm');
    my $short_form = $search->search_web('dist:Pod-Pm');

    is_deeply(
        $long_form->{results},
        $short_form->{results},
        'dist == distribution search'
    );
}

{
    my $id      = 'JatCtNR2RGjcBIs1Y5C_zTzNcXU';
    my $results = $search->search_descriptions($id);
    is_deeply( $results->{results}, { $id => 'TBD' }, 'search_descriptions' );
}

# favorites are also tested in t/server/controller/user/favorite.t
is_deeply( $search->search_favorites, {},
    'empty hashref when no distributions' );

is_deeply( $search->search_favorites('Pod-Pm'), {}, 'no favorites found' );

is_deeply( $search->search_descriptions,
    {}, 'empty hashref when no ids for descriptions' );

done_testing();
