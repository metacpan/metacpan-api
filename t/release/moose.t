use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( model );
use MetaCPAN::Util         qw( true false );
use Test::More;

my $model = model();
my $idx   = $model->index('cpan');
my @moose
    = $idx->type('release')->query( { term => { distribution => 'Moose' } } )
    ->all;

my $first = 0;
map { $first++ } grep { $_->first } @moose;

is( $first, 1, 'only one moose is first' );

is( $moose[0]->main_module, 'Moose', 'main_module ok' );

is( $moose[1]->main_module, 'Moose', 'main_module ok' );

ok(
    my $faq
        = $idx->type('file')
        ->query( { match_phrase => { documentation => 'Moose::FAQ' } } )
        ->first,
    'get Moose::FAQ'
);

is( $faq->status, 'latest', 'is latest' );

ok( $faq->indexed, 'is indexed' );

ok( !$faq->binary, 'is not binary' );

ok(
    my $binary
        = $idx->type('file')->query( { term => { name => 't' } } )->first,
    'get a t/ directory'
);

ok( $binary->binary, 'is binary' );

ok(
    my $ppport
        = $idx->type('file')
        ->query( { match_phrase => { documentation => 'ppport.h' } } )->first,
    'get ppport.h'
);

is( $ppport->name, 'ppphdoc', 'name doesn\'t contain a dot' );

ok( my $moose = $idx->type('file')->find('Moose'), 'find Moose module' );

is( $moose->name, 'Moose.pm', 'defined in Moose.pm' );

is( $moose->module->[0]->associated_pod, 'DOY/Moose-0.02/lib/Moose.pm' );

my $signature;
$signature = $idx->type('file')->query( {
    bool => {
        must => [
            { term => { mime => 'text/x-script.perl' } },
            { term => { name => 'SIGNATURE' } },
        ],
    },
} )->first;
ok( !$signature, 'SIGNATURE is not perl code' );

$signature = $idx->type('file')->query( {
    bool => {
        must => [
            { term => { documentation => 'SIGNATURE' } },
            { term => { mime          => 'text/x-script.perl' } },
            { term => { name          => 'SIGNATURE' } },
        ],
    },
} )->first;
ok( !$signature, 'SIGNATURE is not documentation' );

$signature = $idx->type('file')->query( {
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
    my $files  = $idx->type('file');
    my $module = $files->history( module => 'Moose' )->raw->all;
    my $file   = $files->history( file => 'Moose', 'lib/Moose.pm' )->raw->all;

    is_deeply( $module->{hits}, $file->{hits},
        'history of Moose and lib/Moose.pm match' );
    is( $module->{hits}->{total}, 2, 'two hits' );

    my $pod = $files->history( documentation => 'Moose::FAQ' )->raw->all;
    is( $pod->{hits}->{total}, 1, 'one hit' );
}

done_testing;
