use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::JSON qw(true false);

# Note: we need a release marked as status => latest
# so we're using Versions::PkgVar for now
# perhaps it should be smarter later and find one to try?

my $t = Test::Mojo->new('MetaCPAN::API');

subtest 'collapsed' => sub {
    $t->get_ok( '/v1/search/web', form => { q => 'Versions::PkgVar' } )
        ->status_is(200)->json_is( '/collapsed' => true );

    $t->get_ok( '/v1/search/web', form => { q => 'module:Versions::PkgVar' } )
        ->status_is(200)->json_is( '/collapsed' => false );

    $t->get_ok( '/v1/search/web',
        form => { q => 'module:Versions::PkgVar', collapsed => 1 } )
        ->status_is(200)->json_is( '/collapsed' => true );

    $t->get_ok( '/v1/search/web', form => { q => 'dist:Versions' } )
        ->status_is(200)->json_is( '/collapsed' => false );

    $t->get_ok( '/v1/search/web',
        form => { q => 'dist:Versions', collapsed => 1 } )->status_is(200)
        ->json_is( '/collapsed' => true );

    $t->get_ok( '/v1/search/web', form => { q => 'distribution:Versions' } )
        ->status_is(200)->json_is( '/collapsed' => false );

    $t->get_ok( '/v1/search/web',
        form => { q => 'distribution:Versions', collapsed => 1 } )
        ->status_is(200)->json_is( '/collapsed' => true );
};

subtest 'paging' => sub {
    my $q = 'this';
    $t->get_ok( '/v1/search/web', form => { q => $q } )->status_is(200);
    my $json  = $t->tx->res->json;
    my $total = $json->{total};

    if ( $total <= 1 ) {
        cmp_ok @{ $json->{results} }, '==', $total,
            'results agree with total';
        diag "Only one search result, skipping remaining paging tests\n";
        return;
    }

    diag "Testing paging with $total results\n";
    cmp_ok @{ $json->{results} }, '<=', $total, 'results agree with total';

    # shrink the page size to one, test limit
    $t->get_ok( '/v1/search/web', form => { q => $q, size => 1 } )
        ->status_is(200)->json_is( '/total' => $total, 'total is unchanged' );
    $json = $t->tx->res->json;
    cmp_ok @{ $json->{results} }, '==', 1, 'results has been limited by size';
    my $first = $json->{results}[0]{hits}[0]{id};

    # keep the page size as one, test offset
    $t->get_ok( '/v1/search/web', form => { q => $q, size => 1, from => 1 } )
        ->status_is(200)->json_is( '/total' => $total, 'total is unchanged' );
    $json = $t->tx->res->json;
    cmp_ok @{ $json->{results} }, '==', 1, 'results has been limited by size';
    my $next = $json->{results}[0]{hits}[0]{id};

    isnt $first, $next, 'got a different result';
};

done_testing;

