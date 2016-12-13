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
           "code" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "id" : {
              "ignore_above" : 2048,
              "index" : "not_analyzed",
              "type" : "string"
           },
           "identity" : {
              "dynamic" : "false",
              "properties" : {
                 "key" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 },
                 "name" : {
                    "ignore_above" : 2048,
                    "index" : "not_analyzed",
                    "type" : "string"
                 }
              }
           },
           "looks_human" : {
              "type" : "boolean"
           },
           "passed_captcha" : {
              "format" : "strict_date_optional_time||epoch_millis",
              "type" : "date"
           }
        }
     }';
}

1;
