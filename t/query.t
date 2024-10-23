use strict;
use warnings;

use lib 't/lib';

use MetaCPAN::Query;
use MetaCPAN::Server::Test ();
use Test::More;
use Scalar::Util qw(weaken refaddr);

my $es = MetaCPAN::Server::Test::model->es;

{
    my $query   = MetaCPAN::Query->new( es => $es );
    my $release = $query->release;

    ok $release->isa('MetaCPAN::Query::Release'),
        'release object is correct class';
    is refaddr $release->query, refaddr $query, 'got same parent object';

    weaken $release;
    weaken $query;
    ok !defined $query, 'parent object properly released'
        or diag explain $query;
    ok !defined $release, 'release object properly released'
        or diag explain $release;
}

{
    my $release = MetaCPAN::Query::Release->new( es => $es );
    my $query   = $release->query;

    ok $query->isa('MetaCPAN::Query'), 'query object is correct class';
    is refaddr $query->release, refaddr $release, 'got same child object';

    weaken $release;
    weaken $query;
    ok !defined $query, 'parent object properly released'
        or diag explain $query;
    ok !defined $release, 'release object properly released'
        or diag explain $release;
}

done_testing;
