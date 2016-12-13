package MetaCPAN::Script::Mapping::CPAN::Rating;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "date" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "release" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "author" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "details" : {
              "dynamic" : false,
              "properties" : {
                 "documentation" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "rating" : {
              "type" : "float"
           },
           "distribution" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "helpful" : {
              "dynamic" : false,
              "properties" : {
                 "value" : {
                    "type" : "boolean"
                 },
                 "user" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "user" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           }
        }
     }';
}

1;
