use strict;
use warnings;

use lib 't/lib';

use MetaCPAN::Query::Release ();
use MetaCPAN::Server::Test   ();
use Test::More;

my $query
    = MetaCPAN::Query::Release->new(
    es => MetaCPAN::Server::Test::model->es() );

is( $query->_get_latest_release('DoesNotExist'),
    undef, '_get_latest_release returns undef when release does not exist' );

is( $query->reverse_dependencies('DoesNotExist'),
    undef, 'reverse_dependencies returns undef when release does not exist' );

done_testing();
