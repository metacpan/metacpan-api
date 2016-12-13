package MetaCPAN::Script::Mapping::CPAN::Mirror;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "A_or_CNAME" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "aka_name" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "ccode" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "city" : {
              "fields" : {
                 "analyzed" : {
                    "analyzer" : "standard",
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "store" : true,
                    "type" : "string"
                 }
              },
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
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
           "continent" : {
              "fields" : {
                 "analyzed" : {
                    "analyzer" : "standard",
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "store" : true,
                    "type" : "string"
                 }
              },
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "country" : {
              "fields" : {
                 "analyzed" : {
                    "analyzer" : "standard",
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "store" : true,
                    "type" : "string"
                 }
              },
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "dnsrr" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "freq" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "ftp" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "http" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "inceptdate" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "location" : {
              "type" : "geo_point"
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
           "org" : {
              "fields" : {
                 "analyzed" : {
                    "analyzer" : "standard",
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "store" : true,
                    "type" : "string"
                 }
              },
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "region" : {
              "fields" : {
                 "analyzed" : {
                    "analyzer" : "standard",
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "store" : true,
                    "type" : "string"
                 }
              },
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "reitredate" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "rsync" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "src" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
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
