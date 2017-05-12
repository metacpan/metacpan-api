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
    my $results = $search->search_web('Foo');
    is( scalar @{ $results->{results}->[0] }, 2, 'got results' );
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

is_deeply( $search->search_favorites, {},
    'empty hashref when no distributions' );
is_deeply( $search->search_favorites('Pod-Pm')->{favorites},
    {}, 'no favorites found' );

is_deeply( $search->search_descriptions,
    {}, 'empty hashref when no ids for descriptions' );
done_testing();
