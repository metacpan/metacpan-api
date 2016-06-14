#!/usr/bin/env perl
# PODNAME: get_fields.pl
use Data::Dumper;
use Cpanel::JSON::XS;
use File::Find::Rule;
use File::Basename;
use Path::Class;

my $current_dir = dirname( __FILE__ );
my $author_dir  = Path::Class::Dir->new( $current_dir, '..', 'conf' );
my @files       = File::Find::Rule->file->name( '*.json' )->in( $author_dir );

my %fields;

foreach my $file ( @files ) {
    warn "Processing $file";
    my $hash;

    eval {
        $hash = decode_json( do { local( @ARGV, $/ ) = $file; <> } );
    } or print "\terror in $file: $@";

    while ( my ($author, $info) = each %{$hash} ) {
        my @local_fields       = keys %{$info};
        @fields{@local_fields} = @local_fields;
    }
}

print $_ for sort keys %fields;
