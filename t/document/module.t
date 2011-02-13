use Test::More;
use strict;
use warnings;

use MetaCPAN::Document::Module;
use File::stat;
use Digest::SHA1;
use DateTime;
use MetaCPAN::Util;

my $module =
  MetaCPAN::Document::Module->new( file         => '',
                                   file_id      => 111,
                                   name         => 'Api.pm',
                                   distribution => 'CPAN-API',
                                   author       => 'PERLER',
                                   release      => 'CPAN-API-0.1',
                                   date         => DateTime->now,
                                   abstract     => '' );

my $id = MetaCPAN::Util::digest(qw(PERLER CPAN-API-0.1 Api.pm));
is( $module->id, $id );

done_testing;
