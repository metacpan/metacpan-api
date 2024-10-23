use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( model );
use Test::More;

my $model   = model();
my $release = $model->doc('release')->get( {
    author => 'LOCAL',
    name   => 'File-Changes-1.0'
} );

is( $release->name,         'File-Changes-1.0', 'name ok' );
is( $release->author,       'LOCAL',            'author ok' );
is( $release->version,      '1.0',              'version ok' );
is( $release->main_module,  'File::Changes',    'main_module ok' );
is( $release->changes_file, 'Changes',          'changes_file ok' );

{
    my @files
        = $model->doc('file')
        ->query( { term => { release => 'File-Changes-1.0' } } )->all;

    my ($changes) = grep { $_->name eq 'Changes' } @files;
    ok $changes, 'found Changes';
}

done_testing;
