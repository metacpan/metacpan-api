package MetaCPAN::Script::Mapping::CPAN::File;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "pod" : {
              "index" : "no",
              "fields" : {
                 "analyzed" : {
                    "fielddata" : {
                       "format" : "disabled"
                    },
                    "type" : "string",
                    "analyzer" : "standard",
                    "term_vector" : "with_positions_offsets"
                 }
              },
              "type" : "string"
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
           "directory" : {
              "type" : "boolean"
           },
           "dir" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "indexed" : {
              "type" : "boolean"
           },
           "documentation" : {
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
                 "edge_camelcase" : {
                    "store" : true,
                    "type" : "string",
                    "analyzer" : "edge_camelcase"
                 },
                 "lowercase" : {
                    "store" : true,
                    "type" : "string",
                    "analyzer" : "lowercase"
                 },
                 "edge" : {
                    "store" : true,
                    "type" : "string",
                    "analyzer" : "edge"
                 },
                 "camelcase" : {
                    "store" : true,
                    "type" : "string",
                    "analyzer" : "camelcase"
                 }
              },
              "type" : "string"
           },
           "id" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "module" : {
              "include_in_root" : true,
              "dynamic" : false,
              "type" : "nested",
              "properties" : {
                 "indexed" : {
                    "type" : "boolean"
                 },
                 "authorized" : {
                    "type" : "boolean"
                 },
                 "associated_pod" : {
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
                 }
              }
           },
           "authorized" : {
              "type" : "boolean"
           },
           "pod_lines" : {
              "doc_values" : true,
              "ignore_above" : 2048,
              "index" : "no",
              "type" : "string"
           },
           "download_url" : {
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
              "type" : "string"
           },
           "binary" : {
              "type" : "boolean"
           },
           "version_numified" : {
              "type" : "float"
           },
           "release" : {
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
           "path" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "description" : {
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
           "level" : {
              "type" : "integer"
           },
           "sloc" : {
              "type" : "integer"
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
           "slop" : {
              "type" : "integer"
           },
           "mime" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           }
        }
     }';
}

1;
