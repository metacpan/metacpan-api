package MetaCPAN::Script::Mapping::CVE;

use strict;
use warnings;

sub mapping {
    '{
        "dynamic" : false,
        "properties" : {
           "distribution" : {
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
     }';
}

1;
