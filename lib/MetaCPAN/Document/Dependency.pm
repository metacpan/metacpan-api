package MetaCPAN::Document::Dependency;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document;

with 'ElasticSearchX::Model::Document::EmbeddedRole';

use MetaCPAN::Util;
use MetaCPAN::Types qw( Str );

has [qw(phase relationship module version)] => ( is => 'ro', required => 1 );

__PACKAGE__->meta->make_immutable;
1;
