package MetaCPAN::Script::Mapping::Contributor;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "release_author" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "release_name" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "distribution" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "pauseid" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           }
        }
     }';
}

1;
