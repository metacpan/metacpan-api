package MetaCPAN::Script::Mapping::CPAN::File;

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
           "author" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "authorized" : {
              "type" : "boolean"
           },
           "binary" : {
              "type" : "boolean"
           },
           "date" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "description" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "dir" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "directory" : {
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
           "documentation" : {
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
                 "edge" : {
                    "analyzer" : "edge",
                    "store" : true,
                    "type" : "string"
                 },
                 "edge_camelcase" : {
                    "analyzer" : "edge_camelcase",
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
           "id" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "indexed" : {
              "type" : "boolean"
           },
           "level" : {
              "type" : "integer"
           },
           "maturity" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "mime" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "module" : {
              "dynamic" : false,
              "include_in_root" : true,
              "properties" : {
                 "associated_pod" : {
                    "type" : "string"
                 },
                 "authorized" : {
                    "type" : "boolean"
                 },
                 "indexed" : {
                    "type" : "boolean"
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
                 "version" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "version_numified" : {
                    "type" : "float"
                 }
              },
              "type" : "nested"
           },
           "name" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "path" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "pod" : {
              "fields" : {
                 "analyzed" : {
                    "analyzer" : "standard",
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "term_vector" : "with_positions_offsets",
                    "type" : "string"
                 }
              },
              "index" : "no",
              "type" : "string"
           },
           "pod_lines" : {
              "doc_values" : true,
              "ignore_above" : 2048,
              "index" : "no",
              "type" : "string"
           },
           "release" : {
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
           "sloc" : {
              "type" : "integer"
           },
           "slop" : {
              "type" : "integer"
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
