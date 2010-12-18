#!/usr/bin/perl

=head1 SYNOPSIS

Rework module mappings.

=cut

use Modern::Perl;

use Data::Dump qw( dump );
use Find::Lib '../lib';
use MetaCPAN;

my $metacpan = MetaCPAN->new();
my $es       = $metacpan->es;

put_mapping();

sub put_mapping {

    $es->delete_mapping(
        index => ['cpan'],
        type  => 'module',
    );

    my $result = $es->put_mapping(
        index => ['cpan'],
        type  => 'module',

        #_source => { compress => 1 },
        properties => {
            archive        => { type => "string" },
            author         => { type => "string" },
            distname       => { type => "string" },
            distvname      => { type => "string" },
            download_url   => { type => "string" },
            name           => { type => "string" },
            release_date   => { type => "date" },
            source_url     => { type => "string" },
            version        => { type => "string" },
        }
    );

}

