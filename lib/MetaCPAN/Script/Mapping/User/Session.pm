package MetaCPAN::Script::Mapping::User::Session;

use strict;
use warnings;

sub mapping {
    '{
        "_timestamp" : {
           "enabled" : true
        },
        "dynamic" : "false"
     }';
}

1;
