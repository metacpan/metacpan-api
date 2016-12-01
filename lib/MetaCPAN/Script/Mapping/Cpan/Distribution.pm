package MetaCPAN::Script::Mapping::Cpan::Distribution;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "river" : {
              "dynamic" : true,
              "properties" : {
                 "immediate" : {
                    "type" : "integer"
                 },
                 "bucket" : {
                    "type" : "integer"
                 },
                 "total" : {
                    "type" : "integer"
                 }
              }
           },
           "name" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "bugs" : {
              "dynamic" : true,
              "properties" : {
                 "rt" : {
                    "dynamic" : true,
                    "properties" : {
                       "source" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       },
                       "closed" : {
                          "type" : "integer"
                       },
                       "rejected" : {
                          "type" : "integer"
                       },
                       "resolved" : {
                          "type" : "integer"
                       },
                       "active" : {
                          "type" : "integer"
                       },
                       "patched" : {
                          "type" : "integer"
                       },
                       "stalled" : {
                          "type" : "integer"
                       },
                       "open" : {
                          "type" : "integer"
                       },
                       "new" : {
                          "type" : "integer"
                       }
                    }
                 },
                 "github" : {
                    "dynamic" : true,
                    "properties" : {
                       "source" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       },
                       "open" : {
                          "type" : "integer"
                       },
                       "closed" : {
                          "type" : "integer"
                       },
                       "active" : {
                          "type" : "integer"
                       }
                    }
                 }
              }
           }
        }
     }';
}

1;
