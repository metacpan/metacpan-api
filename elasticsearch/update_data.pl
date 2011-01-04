#!/usr/bin/perl

=head2 SYNOPSIS

The index is created via cron on a different machine. Here we port it over and
restart ES with new data.

eg: perl elasticsearch/update_data.pl --file "http://www.ww5.wundercounter.com/metacpan/data.zip" --elasticsearch "/Users/olaf/Documents/developer/elasticsearch-0.13.1"

=cut

use Archive::Tar::Wrapper;
use Data::Dump qw( dump );
use File::Copy::Recursive qw( dirmove );
use Find::Lib '../lib';
use Getopt::Long::Descriptive;
use MetaCPAN;
use Modern::Perl;
use Path::Class::File;
use WWW::Mechanize;
use WWW::Mechanize::Cached;

my ($opt, $usage) = describe_options(
  'update_data.pl %o',
  [ 'file|f=s', "the location of the data.zip" ],
  [ 'elasticsearch|es=s', "the location of ElasticSearch" ],
  [ 'help',       "print usage message and exit" ],
);

print($usage->text), exit if $opt->help;

my $mech_class = 'WWW::Mechanize::Cached';
my $es       = MetaCPAN->new->es;
my $filename = '/tmp/metacpan_data.zip';
my $file     = Path::Class::File->new( $filename );
my $mech     = $mech_class->new;

$mech->get( $opt->file );
my $fh = $file->openw();
print $fh $mech->content;

my $arch = Archive::Tar::Wrapper->new();
$arch->read( $filename );

$es->shutdown;
dirmove ( $arch->tardir, $opt->elasticsearch );

my $start = $opt->elasticsearch . '/bin/elasticsearch';
`$start`;
