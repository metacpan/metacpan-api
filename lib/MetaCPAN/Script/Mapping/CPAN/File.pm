package MetaCPAN::Script::Mapping::CPAN::File;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : "false",
        "properties" : {
          "abstract" : {
            "type" : "string",
            "index" : "not_analyzed",
            "fields" : {
              "analyzed" : {
                "type" : "string",
                "store" : true,
                "fielddata" : {
                  "format" : "disabled"
                },
                "analyzer" : "standard"
              }
            },
            "ignore_above" : 2048
          },
          "author" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "authorized" : {
            "type" : "boolean"
          },
          "binary" : {
            "type" : "boolean"
          },
          "date" : {
            "type" : "date",
            "format" : "strict_date_optional_time||epoch_millis"
          },
          "description" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "dir" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "directory" : {
            "type" : "boolean"
          },
          "dist_fav_count" : {
            "type" : "integer"
          },
          "distribution" : {
            "type" : "string",
            "index" : "not_analyzed",
            "fields" : {
              "analyzed" : {
                "type" : "string",
                "store" : true,
                "fielddata" : {
                  "format" : "disabled"
                },
                "analyzer" : "standard"
              },
              "camelcase" : {
                "type" : "string",
                "store" : true,
                "analyzer" : "camelcase"
              },
              "lowercase" : {
                "type" : "string",
                "store" : true,
                "analyzer" : "lowercase"
              }
            },
            "ignore_above" : 2048
          },
          "documentation" : {
            "type" : "string",
            "index" : "not_analyzed",
            "fields" : {
              "analyzed" : {
                "type" : "string",
                "store" : true,
                "fielddata" : {
                  "format" : "disabled"
                },
                "analyzer" : "standard"
              },
              "camelcase" : {
                "type" : "string",
                "store" : true,
                "analyzer" : "camelcase"
              },
              "edge" : {
                "type" : "string",
                "store" : true,
                "analyzer" : "edge"
              },
              "edge_camelcase" : {
                "type" : "string",
                "store" : true,
                "analyzer" : "edge_camelcase"
              },
              "lowercase" : {
                "type" : "string",
                "store" : true,
                "analyzer" : "lowercase"
              }
            },
            "ignore_above" : 2048
          },
          "download_url" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "id" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "indexed" : {
            "type" : "boolean"
          },
          "level" : {
            "type" : "integer"
          },
          "maturity" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "mime" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "module" : {
            "type" : "nested",
            "include_in_root" : true,
            "dynamic" : "false",
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
                "type" : "string",
                "index" : "not_analyzed",
                "fields" : {
                  "analyzed" : {
                    "type" : "string",
                    "store" : true,
                    "fielddata" : {
                      "format" : "disabled"
                    },
                    "analyzer" : "standard"
                  },
                  "camelcase" : {
                    "type" : "string",
                    "store" : true,
                    "analyzer" : "camelcase"
                  },
                  "lowercase" : {
                    "type" : "string",
                    "store" : true,
                    "analyzer" : "lowercase"
                  }
                },
                "ignore_above" : 2048
              },
              "version" : {
                "type" : "string",
                "index" : "not_analyzed",
                "ignore_above" : 2048
              },
              "version_numified" : {
                "type" : "float"
              }
            }
          },
          "name" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "path" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "pod" : {
            "type" : "string",
            "index" : "no",
            "fields" : {
              "analyzed" : {
                "type" : "string",
                "term_vector" : "with_positions_offsets",
                "fielddata" : {
                  "format" : "disabled"
                },
                "analyzer" : "standard"
              }
            }
          },
          "pod_lines" : {
            "type" : "string",
            "index" : "no",
            "doc_values" : true,
            "ignore_above" : 2048
          },
          "release" : {
            "type" : "string",
            "index" : "not_analyzed",
            "fields" : {
              "analyzed" : {
                "type" : "string",
                "store" : true,
                "fielddata" : {
                  "format" : "disabled"
                },
                "analyzer" : "standard"
              },
              "camelcase" : {
                "type" : "string",
                "store" : true,
                "analyzer" : "camelcase"
              },
              "lowercase" : {
                "type" : "string",
                "store" : true,
                "analyzer" : "lowercase"
              }
            },
            "ignore_above" : 2048
          },
          "sloc" : {
            "type" : "integer"
          },
          "slop" : {
            "type" : "integer"
          },
          "stat" : {
            "dynamic" : "true",
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
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "suggest" : {
            "type" : "completion",
            "analyzer" : "simple",
            "payloads" : true,
            "preserve_separators" : true,
            "preserve_position_increments" : true,
            "max_input_length" : 50
          },
          "version" : {
            "type" : "string",
            "index" : "not_analyzed",
            "ignore_above" : 2048
          },
          "version_numified" : {
            "type" : "float"
          }
        }
    }';
}

1;
