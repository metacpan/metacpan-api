use strict;
use warnings;

use FindBin;
use File::Temp;
use LWP::Simple qw(getstore);
use MetaCPAN::Model::Tarball;
use MetaCPAN::Script::Runner;
use Test::More;
use Test::RequiresInternet( 'metacpan.org' => 'https' );

my $config = do {

    # build_config expects test to be t/*.t
    local $FindBin::RealBin = "$FindBin::RealBin/..";
    MetaCPAN::Script::Runner->build_config;
};

my $url
    = 'https://cpan.metacpan.org/authors/id/D/DC/DCANTRELL/Acme-Pony-1.1.2.tar.gz';
my $archive_file = File::Temp->new;
getstore $url, $archive_file->filename;
ok -s $archive_file->filename;

my $tarball = MetaCPAN::Model::Tarball->new(
    logger  => $config->{logger},
    level   => $config->{level},
    tarball => $archive_file->filename,
);
$tarball->set_logger_once;

is $tarball->tarball, $archive_file->filename;

# This isn't going to work without a lot more scaffolding passed into Tarball
#my @files = $tarball->get_files();
#is( @files, 4, 'got all files from tarball' );

done_testing();
