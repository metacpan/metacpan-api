use strict;
use warnings;

use FindBin;
use File::Temp;
use LWP::Simple qw(getstore);
use MetaCPAN::Model::Release;
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

my $release = MetaCPAN::Model::Release->new(
    logger => $config->{logger},
    level  => $config->{level},
    file   => $archive_file->filename,
);
$release->set_logger_once;

is $release->file, $archive_file->filename;

# This isn't going to work without a lot more scaffolding passed into Release
#my @files = $release->get_files();
#is( @files, 4, 'got all files from release' );

done_testing();
