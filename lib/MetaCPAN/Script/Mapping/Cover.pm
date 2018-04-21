package MetaCPAN::Script::Mapping::Cover;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "distribution" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "version" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "release" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "criteria": {
              "dynamic" : true,
              "properties" : {
                 "branch" : {
                    "type" : "float"
                 },
                 "condition" : {
                    "type" : "float"
                 },
                 "statement" : {
                    "type" : "float"
                 },
                 "subroutine" : {
                    "type" : "float"
                 },
                 "total" : {
                    "type" : "float"
                 }
              }
           }
        }
     }';
}

1;
