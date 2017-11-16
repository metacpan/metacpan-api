use strict;
use warnings;
use lib 't/lib';

use File::Temp ();
use LWP::Simple qw(getstore);
use MetaCPAN::Model::Release;
use MetaCPAN::Script::Runner;
use MetaCPAN::TestHelpers qw( get_config );
use Test::More;
use Test::RequiresInternet( 'metacpan.org' => 'https' );

my $config = get_config();
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

done_testing();
