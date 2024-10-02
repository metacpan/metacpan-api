#!/bin/sh

/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan backup --index cpan_v1_01 --type favorite
/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan backup --index cpan_v1_01 --type author

/home/metacpan/bin/metacpan-api-carton-exec bin/metacpan backup --index user
