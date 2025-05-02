use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Server::Test qw( es_result query );
use MetaCPAN::Util         qw( true false );
use Test::More;

my @moose = es_result( 'release', { term => { distribution => 'Moose' } } );

my $first = 0;
map { $first++ } grep { $_->{first} } @moose;

is( $first, 1, 'only one moose is first' );

is( $moose[0]->{main_module}, 'Moose', 'main_module ok' );

is( $moose[1]->{main_module}, 'Moose', 'main_module ok' );

my $faq = es_result( 'file',
    { match_phrase => { documentation => 'Moose::FAQ' } } );

ok( $faq, 'get Moose::FAQ' );

is( $faq->{status}, 'latest', 'is latest' );

ok( $faq->{indexed}, 'is indexed' );

ok( !$faq->{binary}, 'is not binary' );

my $binary = es_result(
    'file',
    {
        bool => {
            must => [
                { term => { release => 'Moose-0.01' } },
                { term => { name    => 't' } },
            ],
        },
    }
);

ok( $binary, 'get a t/ directory' );

ok( $binary->{binary}, 'is binary' );

my $ppport = es_result( 'file',
    { match_phrase => { documentation => 'ppport.h' } } );
ok( $ppport, 'get ppport.h' );

is( $ppport->{name}, 'ppphdoc', 'name doesn\'t contain a dot' );

my $signature;
($signature) = es_result(
    'file',
    {
        bool => {
            must => [
                { term => { mime => 'text/x-script.perl' } },
                { term => { name => 'SIGNATURE' } },
            ],
        },
    }
);
ok( !$signature, 'SIGNATURE is not perl code' );

($signature) = es_result(
    'file',
    {
        bool => {
            must => [
                { term => { documentation => 'SIGNATURE' } },
                { term => { mime          => 'text/x-script.perl' } },
                { term => { name          => 'SIGNATURE' } },
            ],
        },
    }
);
ok( !$signature, 'SIGNATURE is not documentation' );

($signature) = es_result(
    'file',
    {
        bool => {
            must => [
                { term   => { name    => 'SIGNATURE' } },
                { exists => { field   => 'documentation' } },
                { term   => { indexed => true } },
            ],
        },
    }
);
ok( !$signature, 'SIGNATURE is not pod' );

{
    my $files  = query()->file;
    my $module = $files->history( module => 'Moose' );
    my $file   = $files->history( file   => 'Moose', 'lib/Moose.pm' );

    is_deeply( $module->{files}, $file->{files},
        'history of Moose and lib/Moose.pm match' );
    is( $module->{total}, 2, 'two hits' );

    my $pod = $files->history( documentation => 'Moose::FAQ' );
    is( $pod->{total}, 1, 'one hit' );
}

done_testing;
