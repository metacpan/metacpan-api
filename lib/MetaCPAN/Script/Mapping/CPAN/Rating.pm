package MetaCPAN::Script::Mapping::CPAN::Rating;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "author" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "date" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
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
           "distribution" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "helpful" : {
              "dynamic" : false,
              "properties" : {
                 "user" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "value" : {
                    "type" : "boolean"
                 }
              }
           },
           "rating" : {
              "type" : "float"
           },
           "release" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
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
