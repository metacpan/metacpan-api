#!/usr/bin/perl

=head2 SYNOPSIS

The index is created via cron on a different machine. Here we port it over and
restart ES with new data.

eg:

perl elasticsearch/update_data.pl --file "http://www.ww5.wundercounter.com/metacpan/data.zip" --elasticsearch "/Users/olaf/Documents/developer/elasticsearch-0.13.1"

=cut

use Archive::Tar::Wrapper;
use Data::Dump qw( dump );
use File::Copy::Recursive qw( dirmove );
use File::stat;
use Find::Lib '../lib';
use Getopt::Long::Descriptive;
use MetaCPAN;
use feature 'say';

my ( $opt, $usage ) = describe_options(
    'update_data.pl %o',
    [ 'file|f=s',           "the location of the archived ElasticSeach data folder" ],
    [ 'elasticsearch|es=s', "the location of ElasticSearch" ],
    [ 'help',               "print usage message and exit" ],
);

print( $usage->text ), exit if ( $opt->help || !$opt->file || !$opt->es );

my $mech_class = 'WWW::Mechanize::Cached';
my $es         = MetaCPAN->new->es;
my $filename   = '/tmp/metacpan_data.zip';

# refresh files more than 12 hours old
if ( !-e $filename || (stat($filename))[9] < time() - 3600 * 12 ) {
    my $wget = "wget -O $filename " . $opt->file;
    `$wget`;
}

my $arch = Archive::Tar::Wrapper->new();
$arch->read( $filename ) || die "cannot read archive";

$es->shutdown;
dirmove( $arch->tardir, $opt->elasticsearch );

my $start = $opt->elasticsearch . '/bin/elasticsearch';
`$start`;
