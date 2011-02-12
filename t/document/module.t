use Test::More;
use strict;
use warnings;

use MetaCPAN::Document::Module;
use File::stat;
use Digest::SHA1;
use DateTime;

my $module =
  MetaCPAN::Document::Module->new( file         => '',
                                   file_id      => 111,
                                   name         => 'Api.pm',
                                   distribution => 'CPAN-API',
                                   author       => 'PERLER',
                                   release      => 'CPAN-API-0.1',
                                   date         => DateTime->now,
                                   abstract     => '' );

my $digest = Digest::SHA1::sha1_base64("PERLER\0CPAN-API-0.1\0Api.pm");
$digest =~ tr/[+\/]/-_/;
is( $module->id, $digest );

done_testing;
