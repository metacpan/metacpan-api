use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test;
use Test::More;

my $model   = model();
my $idx     = $model->index('cpan');
my $release = $idx->type('release')->get( {
    author => 'RWSTAUNER',
    name   => 'perl-1'
} );

is( $release->name,         'perl-1',            'name ok' );
is( $release->author,       'RWSTAUNER',         'author ok' );
is( $release->version,      '1',                 'version ok' );
is( $release->changes_file, 'pod/perldelta.pod', 'changes_file ok' );

done_testing;
