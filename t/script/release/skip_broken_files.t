use strict;
use warnings;

use Archive::Tar;
use File::pushd;
use FindBin;
use HTTP::Request;
use LWP::UserAgent;
use MetaCPAN::Script::Release;
use MetaCPAN::Script::Runner;
use Test::More;
use Test::RequiresInternet ( 'metacpan.org' => 443 );

my $dir = tempd();

my $ua = LWP::UserAgent->new(
    agent      => 'metacpan',
    env_proxy  => 1,
    parse_head => 0,
    timeout    => 30,
);

my $url
    = 'https://cpan.metacpan.org/authors/id/S/SH/SHULL/karma-0.7.0.tar.gz';
my $tarball = 'tarball.tar.gz';

my $req = HTTP::Request->new( GET => $url );
$req->header( Accept => '*/*' );
my $res = $ua->request( $req, $tarball );

my $arch = Archive::Tar->new;
$arch->read($tarball);

my $config = do {

    # build_config expects test to be t/*.t
    local $FindBin::RealBin = "$FindBin::RealBin/../..";
    MetaCPAN::Script::Runner->build_config;
};

my $release = MetaCPAN::Script::Release->new($config);

my $next = Archive::Tar->iter($tarball);
while ( my $file = $next->() ) {
    if ( $file->is_fifo ) {
        ok(
            $release->_is_broken_file($file),
            $file->full_path . ' is a broken pipe'
        );
    }
    elsif ( $file->is_symlink ) {
        ok( $release->_is_broken_file($file),
            $file->full_path . ' is a  broken symlink' );
    }
}

done_testing();
