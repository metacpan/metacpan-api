package MetaCPAN::Script::Mapping::User::Account;

use strict;
use warnings;

sub mapping {
    '{
        "_timestamp" : {
           "enabled" : true
        },
        "dynamic" : "false",
        "properties" : {
           "looks_human" : {
              "type" : "boolean"
           },
           "identity" : {
              "dynamic" : "false",
              "properties" : {
                 "name" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "key" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "access_token" : {
              "dynamic" : "true",
              "properties" : {
                 "client" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "token" : {
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
           "passed_captcha" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           },
           "code" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           }
        }
     }';
}

1;
