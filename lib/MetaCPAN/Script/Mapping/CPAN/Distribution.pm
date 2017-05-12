package MetaCPAN::Script::Mapping::CPAN::Distribution;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "bugs" : {
              "dynamic" : true,
              "properties" : {
                 "github" : {
                    "dynamic" : true,
                    "properties" : {
                       "active" : {
                          "type" : "integer"
                       },
                       "closed" : {
                          "type" : "integer"
                       },
                       "open" : {
                          "type" : "integer"
                       },
                       "source" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       }
                    }
                 },
                 "rt" : {
                    "dynamic" : true,
                    "properties" : {
                       "active" : {
                          "type" : "integer"
                       },
                       "closed" : {
                          "type" : "integer"
                       },
                       "new" : {
                          "type" : "integer"
                       },
                       "open" : {
                          "type" : "integer"
                       },
                       "patched" : {
                          "type" : "integer"
                       },
                       "rejected" : {
                          "type" : "integer"
                       },
                       "resolved" : {
                          "type" : "integer"
                       },
                       "source" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       },
                       "stalled" : {
                          "type" : "integer"
                       }
                    }
                 }
              }
           },
           "name" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "external_package" : {
              "dynamic" : true,
              "properties" : {
                 "debian" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "river" : {
              "dynamic" : true,
              "properties" : {
                 "bucket" : {
                    "type" : "integer"
                 },
                 "immediate" : {
                    "type" : "integer"
                 },
                 "total" : {
                    "type" : "integer"
                 }
              }
           }
        }
     }';
}

1;
