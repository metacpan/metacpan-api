package MetaCPAN::Script::Mapping::Cpan::Favorite;

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
           "user" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "release" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "id" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "author" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "distribution" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           }
        }
     }';
}

1;
