package MetaCPAN::Script::Mapping::CPAN::Release;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "resources" : {
              "include_in_root" : true,
              "dynamic" : true,
              "type" : "nested",
              "properties" : {
                 "repository" : {
                    "include_in_root" : true,
                    "dynamic" : true,
                    "type" : "nested",
                    "properties" : {
                       "web" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       },
                       "url" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       },
                       "type" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       }
                    }
                 },
                 "homepage" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "bugtracker" : {
                    "include_in_root" : true,
                    "dynamic" : true,
                    "type" : "nested",
                    "properties" : {
                       "web" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       },
                       "mailto" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       }
                    }
                 },
                 "license" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "status" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "date" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "author" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "maturity" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "dependency" : {
              "include_in_root" : true,
              "dynamic" : false,
              "type" : "nested",
              "properties" : {
                 "version" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "relationship" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "phase" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "module" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "id" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "authorized" : {
              "type" : "boolean"
           },
           "changes_file" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "download_url" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "first" : {
              "type" : "boolean"
           },
           "archive" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "version" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
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
                 },
                 "lowercase" : {
                    "store" : true,
                    "type" : "string",
                    "analyzer" : "lowercase"
                 },
                 "camelcase" : {
                    "store" : true,
                    "type" : "string",
                    "analyzer" : "camelcase"
                 }
              },
              "type" : "string"
           },
           "version_numified" : {
              "type" : "float"
           },
           "license" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "stat" : {
              "dynamic" : true,
              "properties" : {
                 "uid" : {
                    "type" : "long"
                 },
                 "mtime" : {
                    "type" : "integer"
                 },
                 "mode" : {
                    "type" : "integer"
                 },
                 "size" : {
                    "type" : "integer"
                 },
                 "gid" : {
                    "type" : "long"
                 }
              }
           },
           "distribution" : {
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
                 },
                 "lowercase" : {
                    "store" : true,
                    "type" : "string",
                    "analyzer" : "lowercase"
                 },
                 "camelcase" : {
                    "store" : true,
                    "type" : "string",
                    "analyzer" : "camelcase"
                 }
              },
              "type" : "string"
           },
           "provides" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "tests" : {
              "dynamic" : true,
              "properties" : {
                 "pass" : {
                    "type" : "integer"
                 },
                 "fail" : {
                    "type" : "integer"
                 },
                 "unknown" : {
                    "type" : "integer"
                 },
                 "na" : {
                    "type" : "integer"
                 }
              }
           },
           "abstract" : {
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
           "main_module" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           }
        }
     }';
}

1;
