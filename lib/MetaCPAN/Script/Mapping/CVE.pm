package MetaCPAN::Script::Mapping::CVE;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
          "affected_versions" : {
            "type" : "string"
          },
          "cpansa_id" : {
            "ignore_above" : 2048,
            "index" : "not_analyzed",
            "type" : "string"
          },
          "cves" : {
            "type" : "string"
          },
          "description" : {
            "type" : "string"
          },
          "distribution" : {
            "type" : "string",
            "index" : "not_analyzed"
          },
          "references" : {
            "type" : "string"
          },
          "releases" : {
            "type" : "string",
            "index" : "not_analyzed"
          },
          "reported" : {
            "type" : "date",
            "format" : "strict_date_optional_time||epoch_millis"
          },
          "severity" : {
            "type" : "string"
          },
          "versions" : {
            "type" : "string",
            "index" : "not_analyzed"
          }
        }
      }';
}

1;
