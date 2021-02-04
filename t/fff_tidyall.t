#!/usr/bin/env perl

use strict;
use warnings;
use lib 't/lib';

use Test::Code::TidyAll qw( tidyall_ok );
tidyall_ok( verbose => $ENV{TEST_VERBOSE} );
