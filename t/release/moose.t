use Test::More;
use strict;
use warnings;

use MetaCPAN::Model;

my $model   = MetaCPAN::Model->new( es => ':9900' );
my $idx     = $model->index('cpan');
my @moose = $idx->type('release')->filter(
    {   term => { 'release.distribution' => 'Moose' }
    }
)->all;

my $first = 0;
map { $first++ } grep { $_->first } @moose;

ok($first, 'only one moose is first');

ok(my $faq = $idx->type('file')->filter({
    term => { 'file.documentation' => 'Moose::FAQ' }
})->first, 'get Moose::FAQ');

is($faq->status, 'latest', 'is latest');

ok($faq->indexed, 'is indexed');

ok(!$faq->binary, 'is not binary');

ok(my $binary = $idx->type('file')->filter({
    term => { 'file.name' => 't' }
})->first, 'get a t/ directory');

ok($binary->binary, 'is binary');

ok(my $ppport = $idx->type('file')->filter({
    term => { 'file.documentation' => 'ppport.h' }
})->first, 'get ppport.h');

is($ppport->name, 'ppphdoc', 'name doesn\'t contain a dot');

ok(my $moose = $idx->type('file')->find('Moose'), 'find Moose module');

is($moose->name, 'Moose.pm', 'defined in Moose.pm');

my $signature;
$signature = $idx->type('file')->filter(
  {   and => [
      { term => { mime => 'text/x-script.perl' } },
      { term => { name => 'SIGNATURE' } }
    ]
  }
)->first;
ok(!$signature, 'SIGNATURE is not perl code');
$signature = $idx->type('file')->filter(
  {   and => [
      { term => { 'file.documentation' => 'SIGNATURE' } },
      { term => { mime => 'text/x-script.perl' } },
      { term => { name => 'SIGNATURE' } }
    ]
  }
)->first;
ok(!$signature, 'SIGNATURE is not documentation');

done_testing;
