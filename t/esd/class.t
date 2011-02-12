package Foo;
use Moose;
use ElasticSearch::Document;

has some => ( is => 'ro' );
has name => ( is => 'ro', id => 1 );

use Test::More;
use strict;
use warnings;

is(Foo->meta->get_id_attribute, Foo->meta->get_attribute('name'));
ok(Foo->meta->get_id_attribute->is_required);


done_testing;