package MetaCPAN::Script::Mapping::DeployStatement;

use strict;
use warnings;

sub mapping {
    '{
        "analysis" : {
           "filter" : {
              "edge" : {
                 "max_gram" : 20,
                 "type" : "edge_ngram",
                 "min_gram" : 1
              }
           },
           "analyzer" : {
              "lowercase" : {
                 "tokenizer" : "keyword",
                 "filter" : "lowercase"
              },
              "fulltext" : {
                 "type" : "english"
              },
              "edge_camelcase" : {
                 "filter" : [
                    "lowercase",
                    "edge"
                 ],
                 "tokenizer" : "camelcase",
                 "type" : "custom"
              },
              "edge" : {
                 "filter" : [
                    "lowercase",
                    "edge"
                 ],
                 "tokenizer" : "standard",
                 "type" : "custom"
              },
              "camelcase" : {
                 "filter" : [
                    "lowercase",
                    "unique"
                 ],
                 "type" : "custom",
                 "tokenizer" : "camelcase"
              }
           },
           "tokenizer" : {
              "camelcase" : {
                 "type" : "pattern",
                 "pattern" : "([^\\\\p{L}\\\\d]+)|(?<=\\\\D)(?=\\\\d)|(?<=\\\\d)(?=\\\\D)|(?<=[\\\\p{L}&&[^\\\\p{Lu}]])(?=\\\\p{Lu})|(?<=\\\\p{Lu})(?=\\\\p{Lu}[\\\\p{L}&&[^\\\\p{Lu}]])"
              }
           }
        },
        "index" : {
           "number_of_shards" : 1,
           "mapper" : {
              "dynamic" : false
           },
           "refresh_interval" : "1s",
           "number_of_replicas":1
        }
    }'
}

1;
