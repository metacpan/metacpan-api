use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( model );
use Test::More;

my $model   = model();
my $release = $model->doc('release')->get( {
    author => 'RWSTAUNER',
    name   => 'perl-1'
} );

is( $release->name,         'perl-1',            'name ok' );
is( $release->author,       'RWSTAUNER',         'author ok' );
is( $release->version,      '1',                 'version ok' );
is( $release->changes_file, 'pod/perldelta.pod', 'changes_file ok' );

done_testing;
