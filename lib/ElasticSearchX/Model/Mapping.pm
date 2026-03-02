package ElasticSearchX::Model::Mapping;
use strict;
use warnings;

use MetaCPAN::Model::Hacks;

$ElasticSearchX::Model::Document::Mapping::MAPPING{ESBool}
    = $ElasticSearchX::Model::Document::Mapping::MAPPING{Bool};

1;
