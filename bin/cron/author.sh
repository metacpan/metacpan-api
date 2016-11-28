#!/bin/sh

# export ES_SCRIPT_INDEX=author_01
# /home/metacpan/bin/metacpan-api-carton-exec bin/metacpan author --index author_01

export ES_SCRIPT_INDEX=cpan_v1_01
/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan author --index cpan_v1_01

unset ES_SCRIPT_INDEX