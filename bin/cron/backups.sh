#!/bin/sh

export ES_SCRIPT_INDEX=favorite_01
/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan backup --index favorite_01 --type favorite

export ES_SCRIPT_INDEX=author_01
/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan backup --index author_01 --type author

export ES_SCRIPT_INDEX=user
/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan backup --index user

unset ES_SCRIPT_INDEX