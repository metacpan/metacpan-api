#!/bin/sh

export ES_SCRIPT_INDEX=cpan
/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan backup --index cpan --type favorite
/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan backup --index cpan --type author

export ES_SCRIPT_INDEX=user
/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan backup --index user

unset ES_SCRIPT_INDEX