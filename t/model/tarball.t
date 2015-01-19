use strict;
use warnings;

use LWP::UserAgent;
use MetaCPAN::Model::Tarball;
use Test::More;
use Test::RequiresInternet( 'https://metacpan.org/' => 443 );

my $url
    = 'https://cpan.metacpan.org/authors/id/S/SH/SHULL/karma-0.7.0.tar.gz';
my $ua = LWP::UserAgent->new(
    agent      => 'metacpan',
    env_proxy  => 1,
    parse_head => 0,
    timeout    => 30,
);
my $req = HTTP::Request->new( GET => $url );
$req->header( Accept => '*/*' );
my $res = $ua->request($req);
my $tarball = MetaCPAN::Model::Tarball->new( tarball => $res );

my @files = $tarball->get_files();
ok( scalar @files, 13, 'got all files from tarball' );

done_testing();
