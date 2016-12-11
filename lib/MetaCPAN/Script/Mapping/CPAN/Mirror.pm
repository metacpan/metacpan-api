package MetaCPAN::Script::Mapping::CPAN::Mirror;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "inceptdate" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "contact" : {
              "dynamic" : false,
              "properties" : {
                 "contact_site" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "contact_user" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "reitredate" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "ftp" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "A_or_CNAME" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "city" : {
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
           "rsync" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "http" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "aka_name" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "country" : {
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
           "dnsrr" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "ccode" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "location" : {
              "type" : "geo_point"
           },
           "org" : {
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
           "src" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "region" : {
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
              "type" : "string"
           },
           "note" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "freq" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "continent" : {
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
           "tz" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           }
        }
    }';
}

1;
