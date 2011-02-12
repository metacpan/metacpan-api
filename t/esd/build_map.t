package MyClass;
use Moose;
use ElasticSearch::Document;

has default => ();
has date => ( isa => 'DateTime' );

package main;
use Test::More;
use strict;
use warnings;

is_deeply( MyClass->meta->build_map,
           {  'ignore_conflicts' => 1,
              index              => ['cpan'],
              type               => 'myclass',
              properties         => {
                              'date' => { 'boost' => '1',
                                          'store' => 'yes',
                                          'type'  => 'date'
                              },
                              default => { 'boost' => '1',
                                           'index' => 'not_analyzed',
                                           'store' => 'yes',
                                           'type'  => 'string'
                              } } } );

done_testing;
