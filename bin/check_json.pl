#!/usr/bin/env perl

use 5.010;

use Data::Dumper;
use JSON::XS;

foreach my $file ( @ARGV ) {
    say "Processing $file";
    eval {
        my $hash = decode_json(
            do { local ( @ARGV, $/ ) = $file; <> }
        );
        print Dumper( $hash );
    };

    if ( $@ ) { say "\terror in $file: $@" }
}

