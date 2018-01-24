package MetaCPAN::Script::Mapping::CPAN::Release;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "abstract" : {
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
           "archive" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "author" : {
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
           "date" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "dependency" : {
              "dynamic" : false,
              "include_in_root" : true,
              "properties" : {
                 "module" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "phase" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "relationship" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "version" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              },
              "type" : "nested"
           },
           "deprecated" : {
              "type" : "boolean"
           },
           "distribution" : {
              "fields" : {
                 "analyzed" : {
                    "analyzer" : "standard",
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "store" : true,
                    "type" : "string"
                 },
                 "camelcase" : {
                    "analyzer" : "camelcase",
                    "store" : true,
                    "type" : "string"
                 },
                 "lowercase" : {
                    "analyzer" : "lowercase",
                    "store" : true,
                    "type" : "string"
                 }
              },
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
           "id" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "license" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "main_module" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "maturity" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "name" : {
              "fields" : {
                 "analyzed" : {
                    "analyzer" : "standard",
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "store" : true,
                    "type" : "string"
                 },
                 "camelcase" : {
                    "analyzer" : "camelcase",
                    "store" : true,
                    "type" : "string"
                 },
                 "lowercase" : {
                    "analyzer" : "lowercase",
                    "store" : true,
                    "type" : "string"
                 }
              },
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "provides" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "resources" : {
              "dynamic" : true,
              "include_in_root" : true,
              "properties" : {
                 "bugtracker" : {
                    "dynamic" : true,
                    "include_in_root" : true,
                    "properties" : {
                       "mailto" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       },
                       "web" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       }
                    },
                    "type" : "nested"
                 },
                 "homepage" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "license" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "repository" : {
                    "dynamic" : true,
                    "include_in_root" : true,
                    "properties" : {
                       "type" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       },
                       "url" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       },
                       "web" : {
                          "ignore_above" : 2048,
                          "index" : "not_analyzed",
                          "type" : "string"
                       }
                    },
                    "type" : "nested"
                 }
              },
              "type" : "nested"
           },
           "stat" : {
              "dynamic" : true,
              "properties" : {
                 "gid" : {
                    "type" : "long"
                 },
                 "mode" : {
                    "type" : "integer"
                 },
                 "mtime" : {
                    "type" : "integer"
                 },
                 "size" : {
                    "type" : "integer"
                 },
                 "uid" : {
                    "type" : "long"
                 }
              }
           },
           "status" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "tests" : {
              "dynamic" : true,
              "properties" : {
                 "fail" : {
                    "type" : "integer"
                 },
                 "na" : {
                    "type" : "integer"
                 },
                 "pass" : {
                    "type" : "integer"
                 },
                 "unknown" : {
                    "type" : "integer"
                 }
              }
           },
           "version" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "version_numified" : {
              "type" : "float"
           }
        }
     }';
}

1;
