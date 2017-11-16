use strict;
use warnings;

use MetaCPAN::Model::Search ();
use MetaCPAN::TestServer    ();
use Test::More;
use Test::Deep qw(cmp_deeply ignore);

plan skip_all =>
    "Travis ES bad, see https://travis-ci.org/metacpan/metacpan-api/jobs/301092129"
    if $ENV{TRAVIS};

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
    cmp_deeply( $results, {}, 'no results on fake module' );
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
        $results->{results}->[0]->[0]->{description},
        'razzberry pudding',
        'description included in results'
    );
}

{
    my $id      = 'JatCtNR2RGjcBIs1Y5C_zTzNcXU';
    my $results = $search->search_descriptions($id);
    cmp_deeply( $results->{results}, { $id => 'TBD' },
        'search_descriptions' );
}

# favorites are also tested in t/server/controller/user/favorite.t
cmp_deeply( $search->search_favorites, {},
    'empty hashref when no distributions' );

cmp_deeply(
    $search->search_favorites('Pod-Pm'),
    {
        favorites => {},
        took      => ignore(),
    },
    'no favorites found'
);

cmp_deeply(
    $search->search_descriptions,
    {
        descriptions => {},
        took         => ignore(),
    },
    'empty hashref when no ids for descriptions'
);

done_testing();
