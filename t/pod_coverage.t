#!/usr/bin/env perl

use Test::More skip_all => "turn on when serious about docs";
use Test::Pod::Coverage;
all_pod_coverage_ok({ coverage_class => 'Pod::Coverage::Moose'});
