use strict;
use warnings;

use lib 't/lib';

use MetaCPAN::Query::Release ();
use MetaCPAN::Server::Test   ();
use Test::More;

my $query = MetaCPAN::Query::Release->new(
    es => MetaCPAN::Server::Test::model->es(), );

is( $query->_get_latest_release('DoesNotExist'),
    undef, '_get_latest_release returns undef when release does not exist' );

is( $query->reverse_dependencies('DoesNotExist'),
    undef, 'reverse_dependencies returns undef when release does not exist' );

is(
    $query->_get_provided_modules(
        { author => 'OALDERS', name => 'DOESNOTEXIST', }
    ),
    undef,
    '_get_provided_modules returns undef when modules cannot be found'
);

is_deeply(
    $query->_get_provided_modules(
        { author => 'DOY', name => 'Try-Tiny-0.21', }
    ),
    ['Try::Tiny'],
    '_get_provided_modules returns undef when modules cannot be found'
);

done_testing();
