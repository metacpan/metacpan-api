package MetaCPAN::Script::Mapping::CPAN::Author;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "profile" : {
              "include_in_root" : true,
              "dynamic" : false,
              "type" : "nested",
              "properties" : {
                 "name" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "id" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "fields" : {
                       "analyzed" : {
                          "store" : true,
                          "fielddata" : {
                             "format" : "disabled"
                          },
                          "type" : "string",
                          "analyzer" : "simple"
                       }
                    },
                    "type" : "string"
                 }
              }
           },
           "website" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "email" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "city" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "user" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "updated" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "pauseid" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "country" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "gravatar_url" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "location" : {
              "type" : "geo_point"
           },
           "donation" : {
              "dynamic" : true,
              "properties" : {
                 "name" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "id" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "asciiname" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "fields" : {
                 "analyzed" : {
                    "store" : true,
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "type" : "string",
                    "analyzer" : "standard"
                 }
              },
              "type" : "string"
           },
           "name" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "fields" : {
                 "analyzed" : {
                    "store" : true,
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "type" : "string",
                    "analyzer" : "standard"
                 }
              },
              "type" : "string"
           },
           "region" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "blog" : {
              "dynamic" : true,
              "properties" : {
                 "feed" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "url" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "perlmongers" : {
              "dynamic" : true,
              "properties" : {
                 "url" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "name" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           }
        }
     }';
}

1;
