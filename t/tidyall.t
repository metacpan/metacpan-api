#!/usr/bin/env perl

use strict;
use warnings;
use lib 't/lib';

use Test::Code::TidyAll;
tidyall_ok( verbose => $ENV{TEST_VERBOSE} );
