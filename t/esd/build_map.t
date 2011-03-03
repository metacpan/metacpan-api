package MyClass;
use Moose;
use ElasticSearch::Document;
use ElasticSearch::Document::Types qw(:all);

has default => ();
has date    => ( isa => 'DateTime' );
has loc     => ( isa => Location );

package main;
use Test::More;
use strict;
use warnings;

is_deeply( MyClass->meta->build_map,
           {  index      => 'cpan',
              type       => 'myclass',
              _source => {
                  compress => \1
              },
              properties => {
                              date => { 'boost' => '1',
                                          'store' => 'yes',
                                          'type'  => 'date'
                              },
                              default => { 'boost' => '1',
                                           'index' => 'not_analyzed',
                                           'store' => 'yes',
                                           'type'  => 'string'
                              },
                              loc => { 'boost' => '1',
                                          'store' => 'yes',
                                          'type'  => 'geo_point'
                              },
              }
           } );

done_testing;
