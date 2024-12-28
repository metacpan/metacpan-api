use strict;
use warnings;

use lib 't/lib';

use MetaCPAN::Query;
use MetaCPAN::Server::Test ();
use Test::More;
use Scalar::Util qw(weaken);

my $es = MetaCPAN::Server::Test::model->es;

{
    my $query   = MetaCPAN::Query->new( es => $es );
    my $release = $query->release;

    isa_ok $release, 'MetaCPAN::Query::Release';
    is $release->query, $query, 'got same parent object';

    weaken $release;
    weaken $query;
    is $query,   undef, 'parent object properly released';
    is $release, undef, 'release object properly released';

}

{
    my $release = MetaCPAN::Query::Release->new( es => $es );
    my $query   = $release->query;

    isa_ok $query, 'MetaCPAN::Query';
    is $query->release, $release, 'got same child object';

    weaken $release;
    weaken $query;
    is $query,   undef, 'parent object properly released';
    is $release, undef, 'release object properly released';
}

done_testing;
