use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( model );
use MetaCPAN::Util         qw( true false hit_total );
use Test::More;

my $model = model();
my @moose
    = $model->doc('release')
    ->query( { term => { distribution => 'Moose' } } )->all;

my $first = 0;
map { $first++ } grep { $_->first } @moose;

is( $first, 1, 'only one moose is first' );

is( $moose[0]->main_module, 'Moose', 'main_module ok' );

is( $moose[1]->main_module, 'Moose', 'main_module ok' );

ok(
    my $faq
        = $model->doc('file')
        ->query( { match_phrase => { documentation => 'Moose::FAQ' } } )
        ->first,
    'get Moose::FAQ'
);

is( $faq->status, 'latest', 'is latest' );

ok( $faq->indexed, 'is indexed' );

ok( !$faq->binary, 'is not binary' );

ok(
    my $binary
        = $model->doc('file')->query( { term => { name => 't' } } )->first,
    'get a t/ directory'
);

ok( $binary->binary, 'is binary' );

ok(
    my $ppport
        = $model->doc('file')
        ->query( { match_phrase => { documentation => 'ppport.h' } } )->first,
    'get ppport.h'
);

is( $ppport->name, 'ppphdoc', 'name doesn\'t contain a dot' );

ok( my $moose = $model->doc('file')->find('Moose'), 'find Moose module' );

is( $moose->name, 'Moose.pm', 'defined in Moose.pm' );

is( $moose->module->[0]->associated_pod, 'DOY/Moose-0.02/lib/Moose.pm' );

my $signature;
$signature = $model->doc('file')->query( {
    bool => {
        must => [
            { term => { mime => 'text/x-script.perl' } },
            { term => { name => 'SIGNATURE' } },
        ],
    },
} )->first;
ok( !$signature, 'SIGNATURE is not perl code' );

$signature = $model->doc('file')->query( {
    bool => {
        must => [
            { term => { documentation => 'SIGNATURE' } },
            { term => { mime          => 'text/x-script.perl' } },
            { term => { name          => 'SIGNATURE' } },
        ],
    },
} )->first;
ok( !$signature, 'SIGNATURE is not documentation' );

$signature = $model->doc('file')->query( {
    bool => {
        must => [
            { term   => { name    => 'SIGNATURE' } },
            { exists => { field   => 'documentation' } },
            { term   => { indexed => true } },
        ],
    },
} )->first;
ok( !$signature, 'SIGNATURE is not pod' );

{
    my $files  = $model->doc('file');
    my $module = $files->history( module => 'Moose' )->raw->all;
    my $file   = $files->history( file => 'Moose', 'lib/Moose.pm' )->raw->all;

    is_deeply( $module->{hits}, $file->{hits},
        'history of Moose and lib/Moose.pm match' );
    is( hit_total($module), 2, 'two hits' );

    my $pod = $files->history( documentation => 'Moose::FAQ' )->raw->all;
    is( hit_total($pod), 1, 'one hit' );
}

done_testing;
